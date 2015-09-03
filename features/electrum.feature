@product @check_tor_leaks
Feature: Electrum Bitcoin client
  As a Tails user
  I might want to use a Bitcoin client
  And all Internet traffic should flow only through Tor

  Scenario: A warning will be displayed if Electrum is not persistent
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And the Tails desktop is ready
    And Tor is ready
    And available upgrades have been checked
    And all notifications have disappeared
    When I start Electrum through the GNOME menu
    But persistence for "electrum" is not enabled
    Then I see a warning that Electrum is not persistent

  Scenario: Using a persistent Electrum configuration
    Given the USB drive "current" contains Tails with persistence configured and password "asdf"
    And a computer
    And I start Tails from USB drive "current" and I login with persistence password "asdf"
    And persistence for "electrum" is enabled
    When I start Electrum through the GNOME menu
    But a bitcoin wallet is not present
    Then I am prompted to create a new wallet
    When I create a new bitcoin wallet
    Then a bitcoin wallet is present
    And I see the main Electrum client window
    And I shutdown Tails and wait for the computer to power off
    Given a computer
    And I start Tails from USB drive "current" and I login with persistence password "asdf"
    When I start Electrum through the GNOME menu
    And a bitcoin wallet is present
    And I see the main Electrum client window
    Then Electrum successfully connects to the network
