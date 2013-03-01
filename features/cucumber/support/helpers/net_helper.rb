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

  def initialize(name, bridge_name, ip, ip6)
    @name = name
    @bridge_name = bridge_name
    @ip = ip
    @ip6 = ip6
    @pcap_file = "#{$tmp_dir}/#{name}.pcap"
  end

  # FIXME: Do we also want to keep "dst host #{@ip}"? We should if we
  # want to test the firewall's INPUT dropping.
  def capture(filter="src host #{@ip} or src host #{@ip6}")
    job = IO.popen("/usr/sbin/tcpdump -n -i #{@bridge_name} -w #{@pcap_file} -U #{filter} >/dev/null 2>&1")
    @pid = job.pid
  end

  def stop
    begin
      Process.kill("TERM", @pid)
    rescue
      # noop
    end
  end

  def clear
    if File.exist?(@pcap_file)
      File.delete(@pcap_file)
    end
  end
end
