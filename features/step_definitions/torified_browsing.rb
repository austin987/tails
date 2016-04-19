Then /^there was no traffic sent to the web server on the LAN$/ do
  assert_no_connections(@sniffer.pcap_file) do |host|
    host.address == @web_server_ip_addr and host.port == @web_server_port
  end
end
