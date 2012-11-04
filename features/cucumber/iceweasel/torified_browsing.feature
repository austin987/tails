Feature: Iceweasel must be anonymous.
  In order to be anonymous, the iceweasel web browser must connect through Tor.

  Background:
    Given I restore the background snapshot if it exists
    And a freshly started Tails
    And the network traffic is sniffed
    And I log in to a new session
    And I have a network connection
    And Tor has bootstrapped
    And Iceweasel has autostarted and is not loading a web page
    And the time has synced
    And I save the background snapshot if it does not exist

  Scenario: Opening check.torproject.org in Iceweasel will show the green onion and the congratualtions message.
    When I open the address "https://check.torproject.org" in Iceweasel
    Then I see "IceweaselTorCheck.png" after at most 180 seconds
    And all Internet traffic has only flowed through Tor

  Scenario: Iceweasel should not have any plugins enabled
    When I open the address "about:plugins" in Iceweasel
    Then I see "IceweaselNoPlugins.png" after at most 60 seconds
