require 'packetfu'
require 'ipaddr'

# Extent IPAddr with a private/public address space checks
class IPAddr
  PrivateIPv4Ranges = [
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("255.255.255.255/32")
  ]

  PrivateIPv6Ranges = [
    IPAddr.new("fc00::/7")
  ]

  def private?
    private_ranges = self.ipv4? ? PrivateIPv4Ranges : PrivateIPv6Ranges
    private_ranges.any? { |range| range.include?(self) }
  end

  def public?
    !private?
  end
end

class FirewallLeakCheck
  attr_reader :ipv4_tcp_leaks, :ipv4_nontcp_leaks, :ipv6_leaks, :nonip_leaks, :mac_leaks

  def initialize(pcap_file, options = {})
    options[:accepted_hosts] ||= []
    options[:ignore_lan] ||= true
    @pcap_file = pcap_file
    packets = PacketFu::PcapFile.new.file_to_array(:filename => @pcap_file)
    mac_leaks = Set.new
    ipv4_tcp_packets = []
    ipv4_nontcp_packets = []
    ipv6_packets = []
    nonip_packets = []
    packets.each do |p|
      if PacketFu::EthPacket.can_parse?(p)
        packet = PacketFu::EthPacket.parse(p)
        mac_leaks << packet.eth_saddr
        mac_leaks << packet.eth_daddr
      end

      if PacketFu::TCPPacket.can_parse?(p)
        ipv4_tcp_packets << PacketFu::TCPPacket.parse(p)
      elsif PacketFu::IPPacket.can_parse?(p)
        ipv4_nontcp_packets << PacketFu::IPPacket.parse(p)
      elsif PacketFu::IPv6Packet.can_parse?(p)
        ipv6_packets << PacketFu::IPv6Packet.parse(p)
      elsif PacketFu::Packet.can_parse?(p)
        nonip_packets << PacketFu::Packet.parse(p)
      else
        save_pcap_file
        raise "Found something in the pcap file that cannot be parsed"
      end
    end
    ipv4_tcp_hosts = filter_hosts_from_ippackets(ipv4_tcp_packets,
                                                 options[:ignore_lan])
    accepted = Set.new(options[:accepted_hosts])
    @mac_leaks = mac_leaks
    @ipv4_tcp_leaks = ipv4_tcp_hosts.select { |host| !accepted.member?(host) }
    @ipv4_nontcp_leaks = filter_hosts_from_ippackets(ipv4_nontcp_packets,
                                                     options[:ignore_lan])
    @ipv6_leaks = filter_hosts_from_ippackets(ipv6_packets,
                                              options[:ignore_lan])
    @nonip_leaks = nonip_packets
  end

  def save_pcap_file
    save_failure_artifact("Network capture", @pcap_file)
  end

  # Returns a list of all unique destination IP addresses found in
  # `packets`. Exclude LAN hosts if ignore_lan is set.
  def filter_hosts_from_ippackets(packets, ignore_lan)
    hosts = []
    packets.each do |p|
      candidate = nil
      if p.kind_of?(PacketFu::IPPacket)
        candidate = p.ip_daddr
      elsif p.kind_of?(PacketFu::IPv6Packet)
        candidate = p.ipv6_header.ipv6_daddr
      else
        save_pcap_file
        raise "Expected an IP{v4,v6} packet, but got something else:\n" +
              p.peek_format
      end
      if candidate != nil and (not(ignore_lan) or IPAddr.new(candidate).public?)
        hosts << candidate
      end
    end
    hosts.uniq
  end

  def assert_no_leaks
    err = ""
    if !@ipv4_tcp_leaks.empty?
      err += "The following IPv4 TCP non-Tor Internet hosts were " +
        "contacted:\n" + ipv4_tcp_leaks.join("\n")
    end
    if !@ipv4_nontcp_leaks.empty?
      err += "The following IPv4 non-TCP Internet hosts were contacted:\n" +
        ipv4_nontcp_leaks.join("\n")
    end
    if !@ipv6_leaks.empty?
      err += "The following IPv6 Internet hosts were contacted:\n" +
        ipv6_leaks.join("\n")
    end
    if !@nonip_leaks.empty?
      err += "Some non-IP packets were sent\n"
    end
    if !err.empty?
      save_pcap_file
      raise err
    end
  end

end
