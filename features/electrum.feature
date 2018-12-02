@product @check_tor_leaks
Feature: Electrum Bitcoin client
  As a Tails user
  I might want to use a Bitcoin client
  And all Internet traffic should flow only through Tor

  Scenario: A warning will be displayed if Electrum is not persistent
    Given I have started Tails from DVD without network and logged in
    When I start Electrum through the GNOME menu
    But persistence for "electrum" is not enabled
    And I see a warning that Electrum is not persistent

  #11697
  @fragile
  Scenario: Using a persistent Electrum configuration
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    And the network is plugged
    And Tor is ready
    And available upgrades have been checked
    And all notifications have disappeared
    Then persistence for "electrum" is enabled
    When I start Electrum through the GNOME menu
    But a bitcoin wallet is not present
    Then Electrum starts
    And I am prompted to configure Electrum
    When I follow the Electrum wizard to create a new bitcoin wallet
    Then a bitcoin wallet is present
    And I see the main Electrum client window
    And Electrum successfully connects to the network
    Then I shutdown Tails and wait for the computer to power off
    Given I start Tails from USB drive "__internal" and I login with persistence enabled
    When I start Electrum through the GNOME menu
    But a bitcoin wallet is present
    Then Electrum starts
    And I am prompted to enter my Electrum wallet password
    When I enter my Electrum wallet password
    Then I see the main Electrum client window
    And Electrum successfully connects to the network
