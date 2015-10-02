@product @check_tor_leaks
Feature: Tor stream isolation is effective
  As a Tails user
  I want my Torified sessions to be sensibly isolated from each other to prevent identity correlation

  Background:
    Given a computer
    When I start Tails from DVD and I login
    And I save the state so the background can be restored next scenario

  Scenario: tails-security-check is using the Tails-specific SocksPort
    When I monitor the network connections of tails-security-check
    And I re-run tails-security-check
    Then I see that tails-security-check is properly stream isolated

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
    And the Tor Browser has started and loaded the startup page
    Then I see that Tor Browser is properly stream isolated

  Scenario: Gobby is using the default SocksPort
    When I monitor the network connections of Gobby
    And I start "Gobby" via the GNOME "Internet" applications menu
    And I connect Gobby to "gobby.debian.org"
    Then I see that Gobby is properly stream isolated

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

  Scenario: Explicitly torify-wrapped applications are using the default SocksPort
    When I monitor the network connections of Gobby
    And I run "torify /usr/bin/gobby-0.5" in GNOME Terminal
    And I connect Gobby to "gobby.debian.org"
    Then I see that Gobby is properly stream isolated

  Scenario: Explicitly torsocks-wrapped applications are using the default SocksPort
    When I monitor the network connections of Gobby
    And I run "torsocks /usr/bin/gobby-0.5" in GNOME Terminal
    And I connect Gobby to "gobby.debian.org"
    Then I see that Gobby is properly stream isolated
