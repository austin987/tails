@product @check_tor_leaks
Feature: Keyserver interaction with GnuPG
  As a Tails user
  when I interact with keyservers using various GnuPG tools
  the configured keyserver must be used
  and all Internet traffic should flow only through Tor.

  Background:
    Given a computer
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And the "10CC5BC7" OpenPGP key is not in the live user's public keyring
    And I save the state so the background can be restored next scenario

  Scenario: Fetching OpenPGP keys using GnuPG should work and be done over Tor.
    When I fetch the "10CC5BC7" OpenPGP key using the GnuPG CLI
    Then GnuPG uses the configured keyserver
    And the GnuPG fetch is successful
    And the "10CC5BC7" key is in the live user's public keyring after at most 120 seconds

  Scenario: Fetching OpenPGP keys using Seahorse should work and be done over Tor.
    When I fetch the "10CC5BC7" OpenPGP key using Seahorse
    Then the "10CC5BC7" key is in the live user's public keyring after at most 120 seconds
