require 'uri'

Given /^the only hosts in APT sources are "([^"]*)"$/ do |hosts_str|
  hosts = hosts_str.split(',')
  apt_sources = $vm.execute_successfully(
    "cat /etc/apt/sources.list /etc/apt/sources.list.d/*"
  ).stdout.chomp
  apt_sources.each_line do |line|
    next if ! line.start_with? "deb"
    source_host = URI(line.split[1]).host
    if !hosts.include?(source_host)
      raise "Bad APT source '#{line}'"
    end
  end
end

Given /^no proposed-updates APT suite is enabled$/ do
  apt_sources = $vm.execute_successfully(
    'cat /etc/apt/sources.list /etc/apt/sources.list.d/*'
  ).stdout
  assert_no_match(/\s\S+-proposed-updates\s/, apt_sources)
end

When /^I configure APT to use non-onion sources$/ do
  script = <<-EOF
  use strict;
  use warnings FATAL => "all";
  s{vwakviie2ienjx6t[.]onion}{ftp.us.debian.org};
  s{sgvtcaew4bxjd7ln[.]onion}{security.debian.org};
  s{sdscoq7snqtznauu[.]onion}{deb.torproject.org};
  s{jenw7xbd6tf7vfhp[.]onion}{deb.tails.boum.org};
EOF
  # VMCommand:s cannot handle newlines, and they're irrelevant in the
  # above perl script any way
  script.delete!("\n")
  $vm.execute_successfully(
    "perl -pi -E '#{script}' /etc/apt/sources.list /etc/apt/sources.list.d/*"
  )
end

When /^I make my current APT sources persistent$/ do
  $vm.execute("install -d -m 755 /live/persistence/TailsData_unlocked/apt-sources.list.d")
  $vm.file_append(
    '/live/persistence/TailsData_unlocked/persistence.conf',
    "/etc/apt/sources.list.d  source=apt-sources.list.d,link\n"
  )
  $vm.file_overwrite(
    '/live/persistence/TailsData_unlocked/apt-sources.list.d/persistent.list',
    $vm.file_content($vm.file_glob('/etc/apt/{,*/}*.list'))
  )
end

When /^I update APT using apt$/ do
  recovery_proc = Proc.new do
    step 'I kill the process "apt"'
    $vm.execute('rm -rf /var/lib/apt/lists/*')
  end
  retry_tor(recovery_proc) do
    Timeout::timeout(15*60) do
      $vm.execute_successfully("echo #{@sudo_password} | " +
                               "sudo -S apt update", :user => LIVE_USER)
    end
  end
end

Then /^I install "(.+)" using apt$/ do |package_name|
  recovery_proc = Proc.new do
    step 'I kill the process "apt"'
    $vm.execute("apt purge #{package_name}")
  end
  retry_tor(recovery_proc) do
    Timeout::timeout(2*60) do
      $vm.execute_successfully("echo #{@sudo_password} | " +
                               "sudo -S DEBIAN_PRIORITY=critical apt -y install #{package_name}",
                               :user => LIVE_USER)
    end
  end
end

When /^I start Synaptic$/ do
  step 'I start "Synaptic Package Manager" via GNOME Activities Overview'
  deal_with_polkit_prompt(@sudo_password)
  @synaptic = Dogtail::Application.new('synaptic')
  # The seemingly spurious space is needed because that is how this
  # frame is named...
  @synaptic.child(
    'Synaptic Package Manager ', roleName: 'frame', recursive: false
  )
end

When /^I update APT using Synaptic$/ do
  recovery_proc = Proc.new do
    step 'I kill the process "synaptic"'
    step "I start Synaptic"
  end
  retry_tor(recovery_proc) do
    @synaptic.button('Reload').click
    sleep 10 # It might take some time before APT starts downloading
    try_for(15*60, :msg => "Took too much time to download the APT data") {
      !$vm.has_process?("/usr/lib/apt/methods/tor+http")
    }
    assert_raise(RuntimeError) do
      @synaptic.child(roleName: 'dialog', recursive: false)
        .child('Error', roleName: 'icon', retry: false)
    end
    if !$vm.has_process?("synaptic")
      raise "Synaptic process vanished, did it segfault again?"
    end
  end
end

Then /^I install "(.+)" using Synaptic$/ do |package_name|
  recovery_proc = Proc.new do
    step 'I kill the process "synaptic"'
    $vm.execute("apt -y purge #{package_name}")
    step "I start Synaptic"
  end
  retry_tor(recovery_proc) do
    @synaptic.button('Search').click
    find_dialog = @synaptic.dialog('Find')
    find_dialog.child(roleName: 'text').typeText(package_name)
    find_dialog.button('Search').click
    package_list = @synaptic.child('Installed Version',
                                   roleName: 'table column header').parent
    package_entry = package_list.child(package_name, roleName: 'table cell')
    package_entry.doubleClick
    @synaptic.button('Apply').click
    apply_prompt = nil
    try_for(60) { apply_prompt = @synaptic.dialog('Summary'); true }
    apply_prompt.button('Apply').click
    try_for(4*60) do
      @synaptic.child('Changes applied', roleName: 'frame', recursive: false)
      true
    end
  end
end
