@product
Feature: Keyserver interaction with GnuPG
  As a Tails user
  when I interact with keyservers using various GnuPG tools
  all network traffic should flow only through Tor.

  Background:
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And I have a network connection
    And Tor has built a circuit
    And Iceweasel has autostarted and is not loading a web page
    And the time has synced
    And I have closed all annoying notifications
    And I save the state so the background can be restored next scenario

  Scenario: Fetching PGP keys using the CLI should be done over Tor.
    When I successfully fetch a GnuPG key using the CLI
    Then all Internet traffic has only flowed through Tor

  Scenario: Fetching PGP keys using seahorse should be done over Tor.
    When I run "seahorse"
    And I successfully fetch a GnuPG key using seahorse
    Then all Internet traffic has only flowed through Tor
