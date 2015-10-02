Then /^the hostname should not have been leaked on the network$/ do
  next if @skip_steps_while_restoring_background
  hostname = @vm.execute("hostname").stdout.chomp
  packets = PacketFu::PcapFile.new.file_to_array(:filename => @sniffer.pcap_file)
  packets.each do |p|
    # if PacketFu::TCPPacket.can_parse?(p)
    #   ipv4_tcp_packets << PacketFu::TCPPacket.parse(p)
    if PacketFu::IPPacket.can_parse?(p)
      payload = PacketFu::IPPacket.parse(p).payload
    elsif PacketFu::IPv6Packet.can_parse?(p)
      payload = PacketFu::IPv6Packet.parse(p).payload
    else
      save_pcap_file
      raise "Found something in the pcap file that either is non-IP, or cannot be parsed"
    end
    if payload.match(hostname)
      raise "Hostname leak detected"
    end
  end
end
