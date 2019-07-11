def shipped_openpgp_keys
  shipped_gpg_keys = $vm.execute_successfully('gpg --batch --with-colons --fingerprint --list-key', :user => LIVE_USER).stdout
  openpgp_fingerprints = shipped_gpg_keys.scan(/^fpr:::::::::([A-Z0-9]+):$/).flatten
  return openpgp_fingerprints
end

Then /^the OpenPGP keys shipped with Tails will be valid for the next (\d+) months$/ do |months|
  invalid = Array.new
  shipped_openpgp_keys.each do |key|
    begin
      step "the shipped OpenPGP key #{key} will be valid for the next #{months} months"
    rescue Test::Unit::AssertionFailedError
      invalid << key
      next
    end
  end
  assert(invalid.empty?, "The following key(s) will not be valid in #{months} months: #{invalid.join(', ')}")
end

Then /^the shipped (?:Debian repository key|OpenPGP key ([A-Z0-9]+)) will be valid for the next (\d+) months$/ do |fingerprint, max_months|
  if fingerprint
    cmd = 'gpg'
    user = LIVE_USER
  else
    fingerprint = TAILS_DEBIAN_REPO_KEY
    cmd = 'apt-key adv'
    user = 'root'
  end
  shipped_sig_key_info = $vm.execute_successfully("#{cmd} --batch --list-key #{fingerprint}", :user => user).stdout
  m = /\[expire[ds]: ([0-9-]*)\]/.match(shipped_sig_key_info)
  if m
    expiration_date = Date.parse(m[1])
    assert((expiration_date << max_months.to_i) > DateTime.now,
           "The shipped key #{fingerprint} will not be valid #{max_months} months from now.")
  end
end

Then /^the live user has been setup by live\-boot$/ do
  assert($vm.execute("test -e /var/lib/live/config/user-setup").success?,
         "live-boot failed its user-setup")
  actual_username = $vm.execute(". /etc/live/config/username.conf; " +
                                "echo $LIVE_USERNAME").stdout.chomp
  assert_equal(LIVE_USER, actual_username)
end

Then /^the live user is a member of only its own group and "(.*?)"$/ do |groups|
  expected_groups = groups.split(" ") << LIVE_USER
  actual_groups = $vm.execute("groups #{LIVE_USER}").stdout.chomp.sub(/^#{LIVE_USER} : /, "").split(" ")
  unexpected = actual_groups - expected_groups
  missing = expected_groups - actual_groups
  assert_equal(0, unexpected.size,
         "live user in unexpected groups #{unexpected}")
  assert_equal(0, missing.size,
         "live user not in expected groups #{missing}")
end

Then /^the live user owns its home dir and it has normal permissions$/ do
  home = "/home/#{LIVE_USER}"
  assert($vm.execute("test -d #{home}").success?,
         "The live user's home doesn't exist or is not a directory")
  owner = $vm.execute("stat -c %U:%G #{home}").stdout.chomp
  perms = $vm.execute("stat -c %a #{home}").stdout.chomp
  assert_equal("#{LIVE_USER}:#{LIVE_USER}", owner)
  assert_equal("700", perms)
end

Then /^no unexpected services are listening for network connections$/ do
  for line in $vm.execute_successfully("ss -ltupn").stdout.chomp.split("\n") do
    splitted = line.split(/[[:blank:]]+/)
    proto = splitted[0]
    next unless ['tcp', 'udp'].include?(proto)
    laddr, lport = splitted[4].split(":")
    proc = /users:\(\("([^"]+)"/.match(splitted[6])[1]
    # Services listening on loopback is not a threat
    if /127(\.[[:digit:]]{1,3}){3}/.match(laddr).nil?
      if SERVICES_EXPECTED_ON_ALL_IFACES.include? [proc, laddr, lport] or
         SERVICES_EXPECTED_ON_ALL_IFACES.include? [proc, laddr, "*"]
        puts "Service '#{proc}' is listening on #{laddr}:#{lport} " +
             "but has an exception"
      else
        raise "Unexpected service '#{proc}' listening on #{laddr}:#{lport}"
      end
    end
  end
end

When /^Tails has booted a 64-bit kernel$/ do
  assert($vm.execute("uname -r | grep -qs 'amd64$'").success?,
         "Tails has not booted a 64-bit kernel.")
end

Then /^the VirtualBox guest modules are available$/ do
  assert($vm.execute("modinfo vboxguest").success?,
         "The vboxguest module is not available.")
end

Then /^the support documentation page opens in Tor Browser$/ do
   if @language == 'German'
     expected_title = 'Tails - Hilfe & Support'
     expected_heading = 'Die Dokumentation durchsuchen'
   else
     expected_title = 'Tails - Support'
     expected_heading = 'Search the documentation'
   end
   step "\"#{expected_title}\" has loaded in the Tor Browser"
   if @language == 'German'
     browser_name = 'Tor-Browser'
   else
     browser_name = 'Tor Browser'
   end
   headings = @torbrowser
              .child(expected_title + " - #{browser_name}", roleName: 'frame')
              .children(roleName: 'heading')
   assert(
     headings.any? { |heading| heading.text == expected_heading }
   )
 end

Given /^I plug and mount a USB drive containing a sample PNG$/ do
  @png_dir = share_host_files(Dir.glob("#{MISC_FILES_DIR}/*.png"))
end

Then /^MAT can clean some sample PNG file$/ do
  for png_on_host in Dir.glob("#{MISC_FILES_DIR}/*.png") do
    png_name = File.basename(png_on_host)
    png_on_guest = "/home/#{LIVE_USER}/#{png_name}"
    step "I copy \"#{@png_dir}/#{png_name}\" to \"#{png_on_guest}\" as user \"#{LIVE_USER}\""
    raw_check_cmd = "grep --quiet --fixed-strings --text " +
                    "'Created with GIMP' '#{png_on_guest}'"
    assert($vm.execute(raw_check_cmd, user: LIVE_USER).success?,
           'The comment is not present in the PNG')
    check_before = $vm.execute_successfully("mat --check '#{png_on_guest}'",
                                            :user => LIVE_USER).stdout
    assert(check_before.include?("#{png_on_guest} is not clean"),
           "MAT failed to see that '#{png_on_host}' is dirty")
    $vm.execute_successfully("mat '#{png_on_guest}'", :user => LIVE_USER)
    check_after = $vm.execute_successfully("mat --check '#{png_on_guest}'",
                                           :user => LIVE_USER).stdout
    assert(check_after.include?("#{png_on_guest} is clean"),
           "MAT failed to clean '#{png_on_host}'")
    assert($vm.execute(raw_check_cmd, user: LIVE_USER).failure?,
           'The comment is still present in the PNG')
    $vm.execute_successfully("rm '#{png_on_guest}'")
  end
end



Then /^AppArmor is enabled$/ do
  assert($vm.execute("aa-status").success?, "AppArmor is not enabled")
end

Then /^some AppArmor profiles are enforced$/ do
  assert($vm.execute("aa-status --enforced").stdout.chomp.to_i > 0,
         "No AppArmor profile is enforced")
end

def get_seccomp_status(process)
  assert($vm.has_process?(process), "Process #{process} not running.")
  pid = $vm.pidof(process)[0]
  status = $vm.file_content("/proc/#{pid}/status")
  return status.match(/^Seccomp:\s+([0-9])/)[1].chomp.to_i
end

def get_apparmor_status(pid)
  apparmor_status = $vm.file_content("/proc/#{pid}/attr/current").chomp
  if apparmor_status.include?(')')
    # matches something like     /usr/sbin/cupsd (enforce)
    # and only returns what's in the parentheses
    return apparmor_status.match(/[^\s]+\s+\((.+)\)$/)[1].chomp
  else
    return apparmor_status
  end
end

Then /^the running process "(.+)" is confined with AppArmor in (complain|enforce) mode$/ do |process, mode|
  assert($vm.has_process?(process), "Process #{process} not running.")
  pid = $vm.pidof(process)[0]
  assert_equal(mode, get_apparmor_status(pid))
end

Then /^the running process "(.+)" is confined with Seccomp in (filter|strict) mode$/ do |process,mode|
  status = get_seccomp_status(process)
  if mode == 'strict'
    assert_equal(1, status, "#{process} not confined with Seccomp in strict mode")
  elsif mode == 'filter'
    assert_equal(2, status, "#{process} not confined with Seccomp in filter mode")
  else
    raise "Unsupported mode #{mode} passed"
  end
end

When /^I disable all networking in the Tails Greeter$/ do
  open_greeter_additional_settings()
  @screen.wait_and_click('TailsGreeterNetworkConnection.png', 30)
  @screen.wait_and_click('TailsGreeterDisableAllNetworking.png', 10)
  @screen.wait_and_click("TailsGreeterAdditionalSettingsAdd.png", 10)
end

Then /^the Tor Status icon tells me that Tor is( not)? usable$/ do |not_usable|
  picture = not_usable ? 'TorStatusNotUsable' : 'TorStatusUsable'
  @screen.find("#{picture}.png")
end
