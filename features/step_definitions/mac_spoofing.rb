def all_ethernet_nics
  $vm.execute_successfully(
    "get_all_ethernet_nics", :libs => 'hardware'
  ).stdout.split
end

When /^I disable MAC spoofing in Tails Greeter$/ do
  @screen.wait_and_click("TailsGreeterMACSpoofing.png", 30)
end

Then /^the network device has (its default|a spoofed) MAC address configured$/ do |mode|
  is_spoofed = (mode == "a spoofed")
  nic = "eth0"
  assert_equal([nic], all_ethernet_nics,
               "We only expected NIC #{nic} but these are present: " +
               all_ethernet_nics.join(", "))
  nic_real_mac = $vm.real_mac
  nic_current_mac = $vm.execute_successfully(
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
  is_leaking = mode.nil?
  assert_all_connections(@sniffer.pcap_file) do |c|
    [c.mac_saddr, c.mac_daddr].include?($vm.real_mac) == is_leaking
  end
end

Given /^macchanger will fail by not spoofing and always returns ([\S]+)$/ do |mode|
  $vm.execute_successfully("mv /usr/bin/macchanger /usr/bin/macchanger.orig")
  $vm.execute_successfully("ln -s /bin/#{mode} /usr/bin/macchanger")
end

Given /^no network interface modules can be unloaded$/ do
  # Note that the real /sbin/modprobe is a symlink to /bin/kmod, and
  # for it to run in modprobe compatibility mode the name must be
  # exactly "modprobe", so we just move it somewhere our of the path
  # instead of renaming it ".real" or whatever we usuablly do when
  # diverting executables for wrappers.
  modprobe_divert = "/usr/local/lib/modprobe"
  $vm.execute_successfully(
    "dpkg-divert --add --rename --divert '#{modprobe_divert}' /sbin/modprobe"
  )
  fake_modprobe_wrapper = <<EOF
#!/bin/sh
if echo "${@}" | grep -q -- -r; then
    exit 1
fi
exec '#{modprobe_divert}' "${@}"
EOF
  $vm.file_append('/sbin/modprobe', fake_modprobe_wrapper)
  $vm.execute_successfully("chmod a+rx /sbin/modprobe")
end

When /^see the "Network card disabled" notification$/ do
  robust_notification_wait("MACSpoofNetworkCardDisabled.png", 60)
end

When /^see the "All networking disabled" notification$/ do
  robust_notification_wait("MACSpoofNetworkingDisabled.png", 60)
end

Then /^(\d+|no) network interface(?:s)? (?:is|are) enabled$/ do |expected_nr_nics|
  # note that "no".to_i => 0 in Ruby.
  expected_nr_nics = expected_nr_nics.to_i
  nr_nics = all_ethernet_nics.size
  assert_equal(expected_nr_nics, nr_nics)
end

Then /^the MAC spoofing panic mode disabled networking$/ do
  nm_state = $vm.execute_successfully('systemctl show NetworkManager').stdout
  nm_is_disabled = $vm.pidof('NetworkManager').empty? &&
                   nm_state[/^LoadState=masked$/] &&
                   nm_state[/^ActiveState=inactive$/]
  assert(nm_is_disabled, "NetworkManager was not disabled")
  all_ethernet_nics.each do |nic|
    ["nic_ipv4_addr", "nic_ipv6_addr"].each do |function|
      addr = $vm.execute_successfully(
        "#{function} #{nic}", :libs => 'hardware'
      ).stdout.chomp
      assert_equal("", addr, "NIC #{nic} was assigned address #{addr}")
    end
  end
end
