Then(/^the firewall leak detector has detected (.*?) leaks$/) do |type|
  next if @skip_steps_while_restoring_background
  leaks = FirewallLeakCheck.new(@sniffer.pcap_file, get_all_tor_nodes)
  case type.downcase
  when 'ipv4 tcp'
    if leaks.ipv4_tcp_leaks.empty?
      leaks.save_pcap_file
      raise "Couldn't detect any IPv4 TCP leaks"
    end
  when 'ipv4 non-tcp'
    if leaks.ipv4_nontcp_leaks.empty?
      leaks.save_pcap_file
      raise "Couldn't detect any IPv4 non-TCP leaks"
    end
  when 'ipv6'
    if leaks.ipv6_leaks.empty?
      leaks.save_pcap_file
      raise "Couldn't detect any IPv6 leaks"
    end
  when 'non-ip'
    if leaks.nonip_leaks.empty?
      leaks.save_pcap_file
      raise "Couldn't detect any non-IP leaks"
    end
  else
    raise "Incorrect packet type '#{type}'"
  end
end

Given(/^I disable Tails' firewall$/) do
  next if @skip_steps_while_restoring_background
  @vm.execute("do_not_ever_run_me")
  iptables = @vm.execute("iptables -L -n -v").stdout.chomp.split("\n")
  for line in iptables do
    if !line[/Chain (INPUT|OUTPUT|FORWARD) \(policy ACCEPT/] and
       !line[/pkts[[:blank:]]+bytes[[:blank:]]+target/] and
       !line.empty?
      raise "The Tails firewall was not successfully disabled:\n#{iptables}"
    end
  end
end

When(/^I do a TCP DNS lookup of "(.*?)"$/) do |host|
  next if @skip_steps_while_restoring_background
  lookup = @vm.execute("host -T #{host} #{SOME_DNS_SERVER}", LIVE_USER)
  assert(lookup.success?, "Failed to resolve #{host}:\n#{lookup.stdout}")
end

When(/^I do a UDP DNS lookup of "(.*?)"$/) do |host|
  next if @skip_steps_while_restoring_background
  lookup = @vm.execute("host #{host} #{SOME_DNS_SERVER}", LIVE_USER)
  assert(lookup.success?, "Failed to resolve #{host}:\n#{lookup.stdout}")
end

When(/^I send some ICMP pings$/) do
  next if @skip_steps_while_restoring_background
  # We ping an IP address to avoid a DNS lookup
  ping = @vm.execute("ping -c 5 #{SOME_DNS_SERVER}", LIVE_USER)
  assert(ping.success?, "Failed to ping #{SOME_DNS_SERVER}:\n#{ping.stderr}")
end
