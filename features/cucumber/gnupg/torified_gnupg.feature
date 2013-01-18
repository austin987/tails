Feature: GnuPG must be anonymous.
  In order to be anonymous, the various GnuPG tools must connect
  through Tor when dealing with keyservers.

  Background:
    Given I restore the background snapshot if it exists
    And a freshly started Tails
    And I log in to a new session
    And GNOME has started
    And I have a network connection
    And Tor has built a circuit
    And Iceweasel has autostarted and is not loading a web page
    And the time has synced
    And I have closed all annoying notifications
    And I save the background snapshot if it does not exist

  Scenario: Fetching PGP keys using the CLI should be done over Tor.
    When I successfully fetch a GnuPG key using the CLI
    Then all Internet traffic has only flowed through Tor

  Scenario: Fetching PGP keys using seahorse should be done over Tor.
    When I run "seahorse"
    And I see "SeahorseWindow.png" after at most 30 seconds
    And I successfully fetch a GnuPG key using seahorse
    Then all Internet traffic has only flowed through Tor
