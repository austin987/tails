@product @check_tor_leaks
Feature: Simulate the Tor network with chutney

  Scenario: We're not using the real Tor network
    Given I have started Tails from DVD and logged in and the network is connected
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    And I open the address "https://check.torproject.org" in the Tor Browser
    Then I see "UnsafeBrowserTorCheckFail.png" after at most 30 seconds
