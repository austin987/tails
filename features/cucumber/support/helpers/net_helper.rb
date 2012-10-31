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

class Sniffer

  attr_reader :name, :pcap_file, :pid

  def initialize(name, bridge_name, ip)
    @name = name
    @bridge_name = bridge_name
    @ip = ip
    @pcap_file = "#{ENV['PWD']}/#{name}.pcap"
  end

  # FIXME: What about IPv6? we need filter="... or src host #{@ip6}"
  # below, and while we don't, FirewallLeakCheck won't detect IPv6
  # leaks.
  # FIXME: Do we also want to keep "dst host #{@ip}"? We should if we
  # want to test the firewall's INPUT dropping.
  def capture(filter="src host #{@ip}")
    job = IO.popen("/usr/sbin/tcpdump -n -i #{@bridge_name} -w #{@pcap_file} -U #{filter} >/dev/null 2>&1")
    @pid = job.pid
  end

  def stop
    Process.kill("TERM", @pid)
  end
end
