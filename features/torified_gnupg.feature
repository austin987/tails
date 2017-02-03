@product @check_tor_leaks
Feature: Keyserver interaction with GnuPG
  As a Tails user
  when I interact with keyservers using various GnuPG tools
  the configured keyserver must be used
  and all Internet traffic should flow only through Tor.

  Background:
    Given I have started Tails from DVD and logged in and the network is connected
    And the "10CC5BC7" OpenPGP key is not in the live user's public keyring

  Scenario: Seahorse is configured to use the correct keyserver
   Then Seahorse is configured to use the correct keyserver

  Scenario: Fetching OpenPGP keys using GnuPG should work and be done over Tor.
    When I fetch the "10CC5BC7" OpenPGP key using the GnuPG CLI
    Then GnuPG uses the configured keyserver
    And the GnuPG fetch is successful
    And the "10CC5BC7" key is in the live user's public keyring

  Scenario: Fetching OpenPGP keys using Seahorse should work and be done over Tor.
    When I fetch the "10CC5BC7" OpenPGP key using Seahorse
    And the Seahorse operation is successful
    Then the "10CC5BC7" key is in the live user's public keyring

  Scenario: Fetching OpenPGP keys using Seahorse via the OpenPGP Applet should work and be done over Tor.
    When I fetch the "10CC5BC7" OpenPGP key using Seahorse via the OpenPGP Applet
    And the Seahorse operation is successful
    Then the "10CC5BC7" key is in the live user's public keyring

  Scenario: Syncing OpenPGP keys using Seahorse should work and be done over Tor.
    Given I fetch the "10CC5BC7" OpenPGP key using the GnuPG CLI without any signatures
    And the GnuPG fetch is successful
    And the "10CC5BC7" key is in the live user's public keyring
    But the key "10CC5BC7" has only 2 signatures
    When I start Seahorse
    Then Seahorse has opened
    And I enable key synchronization in Seahorse
    And I synchronize keys in Seahorse
    And the Seahorse operation is successful
    Then the key "10CC5BC7" has more than 2 signatures

  Scenario: Syncing OpenPGP keys using Seahorse started from the OpenPGP Applet should work and be done over Tor.
    Given I fetch the "10CC5BC7" OpenPGP key using the GnuPG CLI without any signatures
    And the GnuPG fetch is successful
    And the "10CC5BC7" key is in the live user's public keyring
    But the key "10CC5BC7" has only 2 signatures
    When I start Seahorse via the OpenPGP Applet
    Then Seahorse has opened
    And I enable key synchronization in Seahorse
    And I synchronize keys in Seahorse
    And the Seahorse operation is successful
    Then the key "10CC5BC7" has more than 2 signatures
