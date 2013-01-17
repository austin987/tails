Feature: Browsing the web using Iceweasel
  As a Tails user
  when I browse the web using Iceweasel
  all network traffic should flow only through Tor

  Background:
    Given I restore the background snapshot if it exists
    And a freshly started Tails
    And I log in to a new session
    And I have a network connection
    And Tor has built a circuit
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
