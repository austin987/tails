#
# There should be a way to tests against network traffic. Possible pathes
# are the use of the pcap gem, use of iptables, or maybe the most promising:
# use the nfqueue gem to be able to inspect packets directly.
#
# Scenario: Iceweasel should connect only through Tor
#   Given I open Iceweasel
#   When I browse to http://any.url
#   Then the network traffic should flow only through Tor
