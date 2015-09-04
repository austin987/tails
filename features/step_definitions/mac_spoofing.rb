def all_ethernet_nics
  @vm.execute_successfully(
    "get_all_ethernet_nics", :libs => 'hardware'
  ).stdout.split
end

When /^disable MAC spoofing in Tails Greeter$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("TailsGreeterMACSpoofing.png", 30)
end

Then /^the network device has (its default|a spoofed) MAC address configured$/ do |mode|
  next if @skip_steps_while_restoring_background
  is_spoofed = (mode == "a spoofed")
  nic = "eth0"
  assert_equal([nic], all_ethernet_nics,
               "We only expected NIC #{nic} but these are present: " +
               all_ethernet_nics.join(", "))
  nic_real_mac = @vm.real_mac
  nic_current_mac = @vm.execute_successfully(
    "get_current_mac_of_nic #{nic}", :libs => 'hardware'
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
  leaks = FirewallLeakCheck.new(@sniffer.pcap_file)
  mac_leaks = leaks.mac_leaks
  if is_leaking
    if !mac_leaks.include?(@vm.real_mac)
      save_pcap_file
      raise "The real MAC address was expected to leak but didn't. We " +
            "observed the following MAC addresses: #{mac_leaks}"
    end
  else
    if mac_leaks.include?(@vm.real_mac)
      save_pcap_file
      raise "The real MAC address was leaked but was expected not to. We " +
            "observed the following MAC addresses: #{mac_leaks}"
    end
  end
end

Given /^macchanger will fail by not spoofing and always returns ([\S]+)$/ do |mode|
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("mv /usr/bin/macchanger /usr/bin/macchanger.orig")
  @vm.execute_successfully("ln -s /bin/#{mode} /usr/bin/macchanger")
end

Given /^MAC spoofing will fail, and the module cannot be unloaded$/ do
  next if @skip_steps_while_restoring_background
  step "macchanger will fail by not spoofing and always returns true"
  @vm.execute_successfully("mv /sbin/rmmod /sbin/rmmod.orig")
  @vm.execute_successfully("ln -s /bin/false /sbin/rmmod")
end

When /^see the "Network card disabled" notification$/ do
  next if @skip_steps_while_restoring_background
  notification_helper("MACSpoofNetworkCardDisabled.png", 60)
end

When /^see the "All networking disabled" notification$/ do
  next if @skip_steps_while_restoring_background
  notification_helper("MACSpoofNetworkingDisabled.png", 60)
end

Then /^(\d+|no) network device(?:s)? (?:is|are) present$/ do |expected_nr_nics|
  next if @skip_steps_while_restoring_background
  # note that "no".to_i => 0 in Ruby.
  expected_nr_nics = expected_nr_nics.to_i
  nr_nics = all_ethernet_nics.size
  assert_equal(expected_nr_nics, nr_nics)
end

Then /^the MAC spoofing panic mode disabled networking$/ do
  next if @skip_steps_while_restoring_background
  nm_is_disabled = not(@vm.file_exist?("/etc/init.d/network-manager")) &&
                   not(@vm.file_exist?("/usr/sbin/NetworkManager"))
  assert(nm_is_disabled, "NetworkManager was not disabled")
  all_ethernet_nics.each do |nic|
    for addr_type in ["nic_ipv4_addr", "nic_ipv6_addr"] do
      addr = @vm.execute_successfully(
        "#{addr_type} #{nic}", :libs => 'hardware'
      ).stdout.chomp
      assert_equal("", addr, "NIC #{nic} was assigned address #{addr}")
    end
  end
end
