When /^no traffic has flowed to the LAN$/ do
  next if @skip_steps_while_restoring_background
  leaks = FirewallLeakCheck.new(@sniffer.pcap_file, :ignore_lan => false)
  assert(not(leaks.ipv4_tcp_leaks.include?(@lan_host)),
         "Traffic was sent to LAN host #{@lan_host}")
end
