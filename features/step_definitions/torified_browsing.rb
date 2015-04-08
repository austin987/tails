When /^I open some LAN resource in the Tor Browser$/ do
  next if @skip_steps_while_restoring_background
  @lan_host = "192.168.0.1"
  step "I open the address \"#{@lan_host}\" in the Tor Browser"
end

When /^no traffic has flowed to the LAN resource$/ do
  next if @skip_steps_while_restoring_background
  leaks = FirewallLeakCheck.new(@sniffer.pcap_file, :ignore_lan => false)
  STDERR.puts "#{leaks.ipv4_tcp_leaks}"
  assert(not(leaks.ipv4_tcp_leaks.include?(@lan_host)),
         "Traffic was sent to LAN host #{@lan_host}")
end
