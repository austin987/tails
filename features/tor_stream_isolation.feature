#17013
@product @check_tor_leaks @fragile
Feature: Tor stream isolation is effective
  As a Tails user
  I want my Tor streams to be sensibly isolated from each other to prevent identity correlation

  Background:
    Given I have started Tails from DVD and logged in and the network is connected

  Scenario: tails-security-check is using the Tails-specific SocksPort
    When I monitor the network connections of tails-security-check
    And I re-run tails-security-check
    Then I see that tails-security-check is properly stream isolated after 10 seconds

  Scenario: htpdate is using the Tails-specific SocksPort
    When I monitor the network connections of htpdate
    And I re-run htpdate
    Then I see that htpdate is properly stream isolated

  Scenario: tails-upgrade-frontend-wrapper is using the Tails-specific SocksPort
    When I monitor the network connections of tails-upgrade-frontend-wrapper
    And I re-run tails-upgrade-frontend-wrapper
    Then I see that tails-upgrade-frontend-wrapper is properly stream isolated

  Scenario: The Tor Browser is using the web browser-specific SocksPort
    When I monitor the network connections of Tor Browser
    And I start the Tor Browser
    And the Tor Browser loads the startup page
    Then I see that Tor Browser is properly stream isolated

  Scenario: SSH is using the default SocksPort
    When I monitor the network connections of SSH
    And I run "ssh lizard.tails.boum.org" in GNOME Terminal
    And I see "SSHAuthVerification.png" after at most 60 seconds
    Then I see that SSH is properly stream isolated

  Scenario: whois lookups use the default SocksPort
    When I monitor the network connections of whois
    And I query the whois directory service for "boum.org"
    And the whois command is successful
    Then I see that whois is properly stream isolated
