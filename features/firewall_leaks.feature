@product
Feature:
  As a Tails developer
  I want to ensure that the automated test suite detects firewall leaks reliably

  Background:
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And all Internet traffic has only flowed through Tor
    And I save the state so the background can be restored next scenario

  Scenario: Detecting IPv4 TCP leaks from the Unsafe Browser
    When I successfully start the Unsafe Browser
    And I open the address "https://check.torproject.org" in the Unsafe Browser
    And I see "UnsafeBrowserTorCheckFail.png" after at most 60 seconds
    Then the firewall leak detector has detected IPv4 TCP leaks

  Scenario: Detecting IPv4 TCP leaks of TCP DNS lookups
    Given I disable Tails' firewall
    When I do a TCP DNS lookup of "torproject.org"
    Then the firewall leak detector has detected IPv4 TCP leaks

  Scenario: Detecting IPv4 non-TCP leaks (UDP) of UDP DNS lookups
    Given I disable Tails' firewall
    When I do a UDP DNS lookup of "torproject.org"
    Then the firewall leak detector has detected IPv4 non-TCP leaks

  Scenario: Detecting IPv4 non-TCP (ICMP) leaks of ping
    Given I disable Tails' firewall
    When I send some ICMP pings
    Then the firewall leak detector has detected IPv4 non-TCP leaks
