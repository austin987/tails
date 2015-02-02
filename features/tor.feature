@product
Feature: Tor is configured properly
  As a Tails user
  I want all direct Internet connections I do by mistake to be blocked

  Background:
    Given a computer
    And I capture all network traffic
    When I start Tails from DVD and I login
    And I save the state so the background can be restored next scenario

  Scenario: The firewall configuration is very restrictive
    Then the firewall's policy is to drop all IPv4 traffic
    And the firewall is configured to only allow the clearnet and debian-tor users to connect directly to the Internet over IPv4
    And the firewall's NAT rules only redirect traffic for Tor's TransPort and DNSPort
    And the firewall is configured to block all IPv6 traffic

  Scenario: The Tor enforcement is effective at blocking untorified connection attempts
    Then untorified network connections to monip.org fails
    And untorified network connections to 1.2.3.4 fails
    And all Internet traffic has only flowed through Tor
