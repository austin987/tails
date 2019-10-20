@product @check_tor_leaks
Feature: Keyserver interaction with GnuPG
  As a Tails user
  when I interact with keyservers using various GnuPG tools
  the configured keyserver must be used
  and all Internet traffic should flow only through Tor.

  Background:
    Given I have started Tails from DVD and logged in and the network is connected
    And the "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" OpenPGP key is not in the live user's public keyring
    And GnuPG is configured to use a non-Onion keyserver
    And Seahorse is configured to use Chutney's onion keyserver

  Scenario: Fetching OpenPGP keys using GnuPG should work and be done over Tor.
    When I fetch the "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" OpenPGP key using the GnuPG CLI
    And the GnuPG fetch is successful
    Then the "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" key is in the live user's public keyring
    And GnuPG's dirmngr uses the configured keyserver

  #14770
  @fragile
  Scenario: Fetching OpenPGP keys using Seahorse should work and be done over Tor.
    When I fetch the "9038E5C6" OpenPGP key using Seahorse
    And the Seahorse operation is successful
    Then the "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" key is in the live user's public keyring

  #14770
  @fragile
  Scenario: Fetching OpenPGP keys using Seahorse via the OpenPGP Applet should work and be done over Tor.
    When I fetch the "9038E5C6" OpenPGP key using Seahorse via the OpenPGP Applet
    And the Seahorse operation is successful
    Then the "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" key is in the live user's public keyring

  #14770
  @fragile
  Scenario: Syncing OpenPGP keys using Seahorse should work and be done over Tor.
    Given I fetch the "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" OpenPGP key using the GnuPG CLI
    And the GnuPG fetch is successful
    And the "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" key is in the live user's public keyring
    And the key "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" has at least 3 subkeys
    And I delete the "88DE00835288C784E73AC940B0A9B7B2D8D2CE47" subkey from the live user's public keyring
    And the key "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" has strictly less than 3 subkeys
    When I start Seahorse
    Then Seahorse has opened
    And I enable key synchronization in Seahorse
    And I synchronize keys in Seahorse
    And the Seahorse operation is successful
    Then the key "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" has at least 3 subkeys

  #14770
  @fragile
  Scenario: Syncing OpenPGP keys using Seahorse started from the OpenPGP Applet should work and be done over Tor.
    Given I fetch the "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" OpenPGP key using the GnuPG CLI
    And the GnuPG fetch is successful
    And the "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" key is in the live user's public keyring
    And the key "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" has at least 3 subkeys
    And I delete the "88DE00835288C784E73AC940B0A9B7B2D8D2CE47" subkey from the live user's public keyring
    And the key "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" has strictly less than 3 subkeys
    When I start Seahorse via the OpenPGP Applet
    Then Seahorse has opened
    And I enable key synchronization in Seahorse
    And I synchronize keys in Seahorse
    And the Seahorse operation is successful
    Then the key "C4BC2DDB38CCE96485EBE9C2F20691179038E5C6" has at least 3 subkeys
