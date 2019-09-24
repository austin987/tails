require 'packetfu'

def looks_like_dhcp_packet?(eth_packet, protocol, sport, dport, ip_packet)
  protocol == "udp" && sport == 68 && dport == 67 && 
    eth_packet.eth_daddr == "ff:ff:ff:ff:ff:ff" &&
    ip_packet && ip_packet.ip_daddr == "255.255.255.255"
end

def is_rarp_packet?(p)
  # Details: https://www.netometer.com/qa/rarp.html#A13
  p.force_encoding("UTF-8").start_with?(
    "\xFF\xFF\xFF\xFF\xFF\xFFRT\x00\xAC\xDD\xEE\x805\x00\x01\b\x00\x06"
  ) && (p[19] == "\x03" || p[19] == "\x04")
end

# Returns the unique edges (based on protocol, source/destination
# address/port) in the graph of all network flows.
def pcap_connections_helper(pcap_file, opts = {})
  opts[:ignore_dhcp] = true unless opts.has_key?(:ignore_dhcp)
  opts[:ignore_arp] = true unless opts.has_key?(:ignore_arp)
  opts[:ignore_sources] ||= [$vm.vmnet.bridge_mac]
  connections = Array.new
  packets = PacketFu::PcapFile.new.file_to_array(:filename => pcap_file)
  packets.each do |p|
    if PacketFu::EthPacket.can_parse?(p)
      eth_packet = PacketFu::EthPacket.parse(p)
    else
      if is_rarp_packet?(p)
        # packetfu cannot parse RARP, see #16825.
        next
      else
        raise FirewallAssertionFailedError.new(
                'Found something that is not an ethernet packet'
              )
      end
    end
    sport = nil
    dport = nil
    if PacketFu::IPv6Packet.can_parse?(p)
      ip_packet = PacketFu::IPv6Packet.parse(p)
      protocol = 'ipv6'
    elsif PacketFu::TCPPacket.can_parse?(p)
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
    elsif PacketFu::ARPPacket.can_parse?(p)
      ip_packet = PacketFu::ARPPacket.parse(p)
      protocol = 'arp'
    else
      raise FirewallAssertionFailedError.new(
              "Found something that cannot be parsed"
            )
    end

    next if opts[:ignore_dhcp] &&
            looks_like_dhcp_packet?(eth_packet, protocol,
                                    sport, dport, ip_packet)
    next if opts[:ignore_arp] && protocol == "arp"
    next if opts[:ignore_sources].include?(eth_packet.eth_saddr)

    packet_info = {
      mac_saddr: eth_packet.eth_saddr,
      mac_daddr: eth_packet.eth_daddr,
      protocol: protocol,
      sport: sport,
      dport: dport,
    }

    begin
      packet_info[:saddr] = ip_packet.ip_saddr
      packet_info[:daddr] = ip_packet.ip_daddr
    rescue NoMethodError, NameError
      begin
        packet_info[:saddr] = ip_packet.ipv6_saddr
        packet_info[:daddr] = ip_packet.ipv6_daddr
      rescue NoMethodError, NameError
        puts "We were hit by #11508. PacketFu bug? Packet info: #{ip_packet}"
        packet_info[:saddr] = nil
        packet_info[:daddr] = nil
      end
    end
    connections << packet_info
  end
  connections.uniq.map { |p| OpenStruct.new(p) }
end

class FirewallAssertionFailedError < Test::Unit::AssertionFailedError
end

# These assertions are made from the perspective of the system under
# testing when it comes to the concepts of "source" and "destination".
def assert_all_connections(pcap_file, opts = {}, &block)
  all = pcap_connections_helper(pcap_file, opts)
  good = all.find_all(&block)
  bad = all - good
  unless bad.empty?
    raise FirewallAssertionFailedError.new(
            "Unexpected connections were made:\n" +
            bad.map { |e| "  #{e}" } .join("\n"))
  end
end

def assert_no_connections(pcap_file, opts = {}, &block)
  assert_all_connections(pcap_file, opts) { |*args| not(block.call(*args)) }
end
