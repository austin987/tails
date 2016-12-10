@product @check_tor_leaks
Feature: Various checks for torified software

  Background:
    Given I have started Tails from DVD and logged in and the network is connected

  Scenario: wget(1) should work for HTTP and go through Tor.
    When I wget "http://example.com/" to stdout
    Then the wget command is successful
    And the wget standard output contains "Example Domain"

  Scenario: wget(1) should work for HTTPS and go through Tor.
    When I wget "https://example.com/" to stdout
    Then the wget command is successful
    And the wget standard output contains "Example Domain"

  Scenario: wget(1) with tricky options should work for HTTP and go through Tor.
    When I wget "some Tails mirror" to stdout with the '--spider --header="Host: dl.amnesia.boum.org"' options
    Then the wget command is successful

  Scenario: whois(1) should work and go through Tor.
    When I query the whois directory service for "torproject.org"
    Then the whois command is successful
    Then the whois standard output contains "The Tor Project"
