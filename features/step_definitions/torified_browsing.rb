When /^I open the LAN web server in the Tor Browser$/ do
  next if @skip_steps_while_restoring_background
  step "I open the address \"#{@lan_web_server_url}\" in the Tor Browser"
end

When /^no traffic has flowed to the LAN web server$/ do
  next if @skip_steps_while_restoring_background
  leaks = FirewallLeakCheck.new(@sniffer.pcap_file, :ignore_lan => false)
  STDERR.puts "#{leaks.ipv4_tcp_leaks}"
  assert(not(leaks.ipv4_tcp_leaks.include?(@lan_host)),
         "Traffic was sent to LAN host #{@lan_host}")
end
