require 'packetfu'

# Returns the unique edges (based on protocol, source/destination
# address/port) in the graph of all network flows.
def pcap_connections_helper(pcap_file, opts = {})
  opts[:ignore_dhcp] ||= true
  connections = Array.new
  packets = PacketFu::PcapFile.new.file_to_array(:filename => pcap_file)
  packets.each do |p|
    if PacketFu::EthPacket.can_parse?(p)
      eth_packet = PacketFu::EthPacket.parse(p)
    else
      raise 'Found something that is not an ethernet packet'
    end
    sport = nil
    dport = nil
    if PacketFu::TCPPacket.can_parse?(p)
      ip_packet = PacketFu::TCPPacket.parse(p)
      protocol = 'tcp'
      sport = ip_packet.tcp_sport
      dport = ip_packet.tcp_dport
    elsif PacketFu::UDPPacket.can_parse?(p)
      ip_packet = PacketFu::UDPPacket.parse(p)
      protocol = 'udp'
      sport = ip_packet.udp_sport
      dport = ip_packet.udp_dport
    elsif PacketFu::ICMPPacket.can_parse?(p)
      ip_packet = PacketFu::ICMPPacket.parse(p)
      protocol = 'icmp'
    elsif PacketFu::IPPacket.can_parse?(p)
      ip_packet = PacketFu::IPPacket.parse(p)
      protocol = 'ip'
    elsif PacketFu::IPv6Packet.can_parse?(p)
      ip_packet = PacketFu::IPv6Packet.parse(p)
      protocol = 'ipv6'
    else
      raise "Found something that cannot be parsed"
    end

    if protocol == "udp" and
       sport == 68 and
       dport == 67 and
       ip_packet.ip_saddr == '0.0.0.0' and
       ip_packet.ip_daddr == "255.255.255.255"
      next if opts[:ignore_dhcp]
    end

    connections << {
      mac_saddr: eth_packet.eth_saddr,
      mac_daddr: eth_packet.eth_daddr,
      protocol: protocol,
      saddr: ip_packet.ip_saddr,
      daddr: ip_packet.ip_daddr,
      sport: sport,
      dport: dport,
    }
  end
  connections.uniq.map { |p| OpenStruct.new(p) }
end

# These assertions are made from the perspective of the system under
# testing when it comes to the concepts of "source" and "destination".
def assert_all_connections(pcap_file, opts = {}, &block)
  all = pcap_connections_helper(pcap_file, opts)
  good = all.find_all(&block)
  bad = all - good
  save_failure_artifact("Network capture", pcap_file) unless bad.empty?
  assert(bad.empty?, "Unexpected connections were made:\n" +
                     bad.map { |e| "  #{e}" } .join("\n"))
end

def assert_no_connections(pcap_file, opts = {}, &block)
  assert_all_connections(pcap_file, opts) { |*args| not(block.call(*args)) }
end
