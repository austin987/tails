When /^disable MAC spoofing in Tails Greeter$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("TailsGreeterMACSpoofing.png", 30)
end

Then /^the network device has (its default|a spoofed) MAC address configured$/ do |mode|
  next if @skip_steps_while_restoring_background
  is_spoofed = (mode == "a spoofed")
  nic = "eth0"
  nic_exists = @vm.execute(
    ". /usr/local/lib/tails-shell-library/hardware.sh && " +
    "nic_exists #{nic}"
  ).success?
  next if !nic_exists
  nic_real_mac = @vm.real_mac
  nic_current_mac = @vm.execute_successfully(
    ". /usr/local/lib/tails-shell-library/hardware.sh && " +
    "get_current_mac_of_nic #{nic}"
  ).stdout.chomp
  if is_spoofed
    if nic_real_mac == nic_current_mac
      save_pcap_file
      raise "The MAC address was expected to be spoofed but wasn't"
    end
  else
    if nic_real_mac != nic_current_mac
      save_pcap_file
      raise "The MAC address is spoofed but was expected to not be"
    end
  end
end

Then /^the real MAC address was (not )?leaked$/ do |mode|
  next if @skip_steps_while_restoring_background
  is_leaking = mode.nil?
  leaks = FirewallLeakCheck.new(@sniffer.pcap_file, [])
  mac_leaks = leaks.mac_leaks
  if is_leaking
    if !mac_leaks.include?(@vm.real_mac)
      save_pcap_file
      raise "The real MAC address was expected to leak but didn't"
    end
  else
    if mac_leaks.include?(@vm.real_mac)
      save_pcap_file
      raise "The real MAC address was leaked but was expected not to"
    end
  end
end

Given /^MAC spoofing will fail by not spoofing and always returns ([\S]+)$/ do |mode|
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("mv /usr/bin/macchanger /usr/bin/macchanger.orig")
  @vm.execute_successfully("ln -s /bin/#{mode} /usr/bin/macchanger")
end

Given /^MAC spoofing will fail, and the module cannot be unloaded$/ do
  next if @skip_steps_while_restoring_background
  step "MAC spoofing will fail by not spoofing and always returns true"

  # TODO: Make `modprove -r e1000` fail some how, perhaps by creating
  # a wrapper that fails specifically for the "-r e1000" argument but
  # operates normally for anything else. Or make tails-mac-spoof use
  # rmmod instead, and symlink it to /bin/false.
  STDERR.puts "NOT IMPLEMENTED"
end

When /^see the "Network card disabled" notification$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("MACSpoofNetworkCardDisabled.png", 60)
end

When /^see the "All networking disabled" notification$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("MACSpoofNetworkingDisabled.png", 60)
end

Then /^the network device was (not )?removed$/ do |mode|
  next if @skip_steps_while_restoring_background
  nic = "eth0"
  nic_expected_to_exist = (mode == "not ")
  nic_exists = @vm.execute(
    ". /usr/local/lib/tails-shell-library/hardware.sh && " +
    "nic_exists #{nic}"
  ).success?
  assert_equal(nic_expected_to_exist, nic_exists)
end

Then /^networking was disabled$/ do
  next if @skip_steps_while_restoring_background
  networking_enabled = @vm.execute("service network-manager status").success?
  assert(!networking_enabled)
end
