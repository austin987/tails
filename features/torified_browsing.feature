@product
Feature: Browsing the web using the Tor Browser
  As a Tails user
  when I browse the web using the Tor Browser
  all Internet traffic should flow only through Tor

  Background:
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And available upgrades have been checked
    And all notifications have disappeared
    And I save the state so the background can be restored next scenario

  Scenario: The Tor Browser uses TBB's shared libraries
    When I start the Tor Browser
    And the Tor Browser has started
    Then the Tor Browser uses all expected TBB shared libraries

  Scenario: Opening check.torproject.org in the Tor Browser shows the green onion and the congratulations message
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    And I open the address "https://check.torproject.org" in the Tor Browser
    Then I see "TorBrowserTorCheck.png" after at most 180 seconds
    And all Internet traffic has only flowed through Tor

  Scenario: The Tor Browser should not have any plugins enabled
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    Then the Tor Browser has no plugins installed
