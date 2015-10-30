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
  leaks = FirewallLeakCheck.new(@sniffer.pcap_file)
  mac_leaks = leaks.mac_leaks
  if is_leaking
    if !mac_leaks.include?($vm.real_mac)
      save_pcap_file
      raise "The real MAC address was expected to leak but didn't. We " +
            "observed the following MAC addresses: #{mac_leaks}"
    end
  else
    if mac_leaks.include?($vm.real_mac)
      save_pcap_file
      raise "The real MAC address was leaked but was expected not to. We " +
            "observed the following MAC addresses: #{mac_leaks}"
    end
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

Then /^I see the "Network connection blocked\?" notification$/ do
  robust_notification_wait("MACSpoofNetworkBlocked.png", 60)
end

Then /^(\d+|no) network interface(?:s)? (?:is|are) enabled$/ do |expected_nr_nics|
  # note that "no".to_i => 0 in Ruby.
  expected_nr_nics = expected_nr_nics.to_i
  nr_nics = all_ethernet_nics.size
  assert_equal(expected_nr_nics, nr_nics)
end

Then /^the MAC spoofing panic mode disabled networking$/ do
  nm_is_disabled = not($vm.file_exist?("/etc/init.d/network-manager")) &&
                   not($vm.file_exist?("/usr/sbin/NetworkManager"))
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

Given /^a wireless NIC's MAC address is blocked by the network$/ do
  device = 'wlan0'
  test_ssid = 'test-ssid'
  # The below log was recorded from Tails based on Debian Wheezy. We
  # should update it and this comment whenever we rebase Tails on a
  # different version of Debian, or install a new version of
  # NetworkManager.
  network_manager_info_log_entries = <<-EOF
    Activation (#{device}) starting connection '#{test_ssid}'
    (#{device}): device state change: disconnected -> prepare (reason 'none') [30 40 0]
    Activation (#{device}) Stage 1 of 5 (Device Prepare) scheduled...
    Activation (#{device}) Stage 1 of 5 (Device Prepare) started...
    Activation (#{device}) Stage 2 of 5 (Device Configure) scheduled...
    Activation (#{device}) Stage 1 of 5 (Device Prepare) complete.
    Activation (#{device}) Stage 2 of 5 (Device Configure) starting...
    (#{device}): device state change: prepare -> config (reason 'none') [40 50 0]
    Activation (#{device}/wireless): access point '#{test_ssid}' has security, but secrets are required.
    (#{device}): device state change: config -> need-auth (reason 'none') [50 60 0]
    Activation (#{device}) Stage 2 of 5 (Device Configure) complete.
get_secret_flags: assertion `is_secret_prop (setting, secret_name, error)' failed
    Activation (#{device}) Stage 1 of 5 (Device Prepare) scheduled...
    Activation (#{device}) Stage 1 of 5 (Device Prepare) started...
    (#{device}): device state change: need-auth -> prepare (reason 'none') [60 40 0]
    Activation (#{device}) Stage 2 of 5 (Device Configure) scheduled...
    Activation (#{device}) Stage 1 of 5 (Device Prepare) complete.
    Activation (#{device}) Stage 2 of 5 (Device Configure) starting...
    (#{device}): device state change: prepare -> config (reason 'none') [40 50 0]
    Activation (#{device}/wireless): connection '#{test_ssid}' has security, and secrets exist.  No new secrets needed.
    Config: added 'ssid' value '#{test_ssid}'
    Config: added 'scan_ssid' value '1'
    Config: added 'key_mgmt' value 'WPA-PSK'
    Config: added 'auth_alg' value 'OPEN'
    Config: added 'psk' value '<omitted>'
    Activation (#{device}) Stage 2 of 5 (Device Configure) complete.
    Config: set interface ap_scan to 1
    (#{device}): supplicant interface state: inactive -> scanning
    (#{device}): supplicant interface state: scanning -> authenticating
    (#{device}): supplicant interface state: authenticating -> associating #{device}: link becomes ready
    Activation (#{device}/wireless): association took too long.
EOF
  tag = 'NetworkManager[666]'
  network_manager_info_log_entries.split("\n").each do |line|
    line.lstrip!
    line.gsub!(/(\"|\`)/) { |match| "\\" + match }
    $vm.execute_successfully("logger -t \"#{tag}\" \"<info> #{line}\"")
  end
end
