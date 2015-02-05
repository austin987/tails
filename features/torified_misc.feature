@product
Feature: Various checks for torified software

  Background:
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And I save the state so the background can be restored next scenario

  Scenario: wget(1) should work for HTTP and go through Tor.
    When I wget "http://example.com/" to stdout
    Then the wget command is successful
    And the wget standard output contains "Example Domain"
    And all Internet traffic has only flowed through Tor

  Scenario: wget(1) should work for HTTPS and go through Tor.
    When I wget "https://example.com/" to stdout
    Then the wget command is successful
    And the wget standard output contains "Example Domain"
    And all Internet traffic has only flowed through Tor

  Scenario: wget(1) with tricky options should work for HTTP and go through Tor.
    When I wget "http://195.154.14.189/tails/stable/" to stdout with the '--spider --header="Host: dl.amnesia.boum.org"' options
    Then the wget command is successful
    And all Internet traffic has only flowed through Tor

  Scenario: whois(1) should work and go through Tor.
    When I query the whois directory service for "torproject.org"
    Then the whois command is successful
    Then the whois standard output contains "The Tor Project"
    And all Internet traffic has only flowed through Tor
