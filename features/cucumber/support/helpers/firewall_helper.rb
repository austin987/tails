require 'packetfu'
require 'ipaddr'

# Extent IPAddr with a private/public address space checks
class IPAddr
  PrivateIPv4Ranges = [
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16")
  ]

  # Tails' firewall apparently leaks multicast ff02::1 == "all
  # (link-local) nodes address"
  PrivateIPv6Ranges = [
    IPAddr.new("fc00::/7"),   # private
    IPAddr.new("ff02::1/64")  # link-local multicast
  ]

  def private?
    if self.ipv4?
      PrivateIPv4Ranges.each do |ipr|
        return true if ipr.include?(self)
      end
      return false
    else
      PrivateIPv6Ranges.each do |ipr|
        return true if ipr.include?(self)
      end
      return false
    end
  end

  def public?
    !private?
  end
end

class FirewallLeakCheck
  attr_reader :ipv4_tcp_leaks, :ipv4_nontcp_leaks, :ipv6_leaks

  def initialize(pcap_file, tor_relays)
    packets = PacketFu::PcapFile.new.file_to_array(:filename => pcap_file)
    @tor_relays = tor_relays
    ipv4_tcp_packets = []
    ipv4_nontcp_packets = []
    ipv6_packets = []
    packets.each do |p|
      if PacketFu::TCPPacket.can_parse?(p)
        ipv4_tcp_packets << PacketFu::TCPPacket.parse(p)
      elsif PacketFu::IPPacket.can_parse?(p)
        ipv4_nontcp_packets << PacketFu::IPPacket.parse(p)
      elsif PacketFu::IPv6Packet.can_parse?(p)
        ipv6_packets << PacketFu::IPv6Packet.parse(p)
      end
    end
    ipv4_tcp_hosts = get_public_hosts_from_ippackets ipv4_tcp_packets
    tor_nodes = Set.new(get_all_tor_contacts)
    @ipv4_tcp_leaks = ipv4_tcp_hosts.select{|host| !tor_nodes.member?(host)}
    @ipv4_nontcp_leaks = get_public_hosts_from_ippackets ipv4_nontcp_packets
    @ipv6_leaks = get_public_hosts_from_ippackets ipv6_packets
  end

  # Returns a list of all unique non-LAN destination IP addresses
  # found in `packets`.
  def get_public_hosts_from_ippackets(packets)
    hosts = []
    packets.each do |p|
      candidate = nil
      # TCPPacket is not a subclass of IPPacket. Ugly!
      if p.instance_of?(PacketFu::IPPacket) or
          p.instance_of?(PacketFu::TCPPacket)
        candidate = p.ip_daddr
      elsif p.instance_of?(PacketFu::IPv6Packet)
        candidate = p.ipv6_header.ipv6_daddr
      end
      if candidate != nil and IPAddr.new(candidate).public?
        hosts << candidate
      end
    end
    hosts.uniq
  end

  # Returns an array of all Tor relays and authorities, i.e. all
  # Internet hosts Tails ever should contact.
  def get_all_tor_contacts
    # List grabbed from Tor's sources, src/or/config.c:~750.
    # FIXME: This is a static list. Can we fetch it reliably from
    # somewhere? With authentication? Up-to-date info?
    tor_authorities = ["128.31.0.39", "86.59.21.38", "194.109.206.212",
                       "82.94.251.203", "76.73.17.194", "212.112.245.170",
                       "193.23.244.244", "208.83.223.34", "171.25.193.9",
                       "154.35.32.5"]
    @tor_relays + tor_authorities
  end

  def empty?
    @ipv4_tcp_leaks.empty? and @ipv4_nontcp_leaks.empty? and @ipv6_leaks.empty?
  end

end
