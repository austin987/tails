require 'uri'

Given /^the only hosts in APT sources are "([^"]*)"$/ do |hosts_str|
  hosts = hosts_str.split(',')
  $vm.file_content("/etc/apt/sources.list /etc/apt/sources.list.d/*").chomp.each_line { |line|
    next if ! line.start_with? "deb"
    source_host = URI(line.split[1]).host
    if !hosts.include?(source_host)
      raise "Bad APT source '#{line}'"
    end
  }
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
                               "sudo -S apt install #{package_name}",
                               :user => LIVE_USER)
    end
  end
end

When /^I start Synaptic$/ do
  step 'I start "Synaptic Package Manager" via the GNOME "System Tools" applications menu'
  deal_with_polkit_prompt(@sudo_password)
  @synaptic = Dogtail::Application.new('synaptic')
  # The seemingly spurious space is needed because that is how this
  # frame is named...
  @synaptic.child('Synaptic Package Manager ', roleName: 'frame',
                  recursive: false).wait
end

When /^I update APT using Synaptic$/ do
  recovery_proc = Proc.new do
    step 'I kill the process "synaptic"'
    step "I start Synaptic"
  end
  retry_tor(recovery_proc) do
    @synaptic.button('Reload').click
    try_for(15*60, :msg => "Took too much time to download the APT data") {
      !$vm.has_process?("/usr/lib/apt/methods/tor+http")
    }
    if @synaptic.child(roleName: 'dialog', recursive: false).child('Error', roleName: 'icon', retry: false).exist?
      raise "Updating APT with Synaptic failed."
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
    find_dialog.wait(10)
    find_dialog.child(roleName: 'text').typeText(package_name)
    find_dialog.button('Search').click
    package_list = @synaptic.child('Installed Version',
                                   roleName: 'table column header').parent
    package_entry = package_list.child(package_name, roleName: 'table cell')
    package_entry.doubleClick
    @synaptic.button('Apply').click
    apply_prompt = @synaptic.dialog('Summary')
    apply_prompt.wait(60)
    apply_prompt.button('Apply').click
    @synaptic.child('Changes applied', roleName: 'frame',
                    recursive: false).wait(4*60)
  end
end
