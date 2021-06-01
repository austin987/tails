@product @check_tor_leaks
Feature: Keyserver interaction with GnuPG
  As a Tails user
  when I interact with keyservers using various GnuPG tools
  the configured keyserver must be used
  and all Internet traffic should flow only through Tor.

  Scenario: Fetching OpenPGP keys using GnuPG should work and be done over Tor
    Given I have started Tails from DVD and logged in and the network is connected
    And the "DF841752B55CD97FDA4879B29E5B04F430F80A2C" OpenPGP key is not in the live user's public keyring
    And GnuPG is configured to use a non-Onion keyserver
    When I fetch the "DF841752B55CD97FDA4879B29E5B04F430F80A2C" OpenPGP key using the GnuPG CLI
    And the GnuPG fetch is successful
    Then the "DF841752B55CD97FDA4879B29E5B04F430F80A2C" key is in the live user's public keyring
    And GnuPG's dirmngr uses the configured keyserver
