@product
Feature: Using Tails with Tor bridges
  As a Tails user
  I want to circumvent censorship of Tor by using Tor bridges

  Background:
    Given a computer
    And the network is unplugged
    And I start the computer
    And the computer boots Tails
    And I enable more Tails Greeter options
    And I enable the specific Tor configuration option
    And I log in to a new session
    And GNOME has started
    And I save the state so the background can be restored next scenario

  Scenario: Using obfs3 bridges
    When the network is plugged
    And the Tor Launcher autostarts
    And I configure some obfs3 bridges in Tor Launcher
    Then Tor is ready
    And available upgrades have been checked
