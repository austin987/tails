#
# Sniffer is a very dumb wrapper to start and stop tcpdumps instances, possibly
# with customized filters. Captured traffic is stored in files whose name
# depends on the sniffer name. The resulting captured packets for each sniffers
# can be accessed as an array through its `packets` method.
#
# Use of more jrubyish internal ways to sniff a network like with pcap-able gems
# is waaay to much resource consumming, notmuch reliable and soooo slow. Let's
# not bother too much with that. :)
#
# Scenario: Iceweasel should connect only through Tor
#   Given I open Iceweasel
#   When I browse to http://any.url
#   Then the network traffic should flow only through Tor

# Should put all that in a Module.

require 'packetfu'

class Sniffer

  attr_reader :name, :pcap_file, :pid

  # TODO: some parameters here should rather be variables from the VM class
  # (iface, ip)
  def initialize(name, br_iface, ip)
    @name = name
    @br_iface = br_iface
    @ip = ip
    @pcap_file = "#{ENV['PWD']}/#{name}.pcap"
  end

  def capture(filter="tcp and src host #{@ip}")
    # TODO: Eventually find a more quiet on exit app than tcpdump.
    job = IO.popen("tcpdump -i #{@br_iface} -w #{@pcap_file} -U #{filter}")
    @pid = job.pid
  end

  def stop
    Process.kill("TERM", @pid)
  end

  # Return an array of PacketFu packets from @pcap_file ready to be parsed.
  def packets
    p = PacketFu::PcapFile.new.file_to_array(:filename => @pcap_file)
    pkts = []
    p.each {|packet| pkts << PacketFu::Packet.parse(packet)}
    pkts
  end

end
