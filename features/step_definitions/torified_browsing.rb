Then /^no traffic was sent to the web server on the LAN$/ do
  assert_no_connections(@sniffer.pcap_file) do |c|
    c.daddr == @web_server_ip_addr and c.dport == @web_server_port
  end
end
