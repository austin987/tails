@product
Feature: Using Tails with Tor pluggable transports
  As a Tails user
  I want to circumvent censorship of Tor by using Tor pluggable transports
  And avoid connecting directly to the Tor Network

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

  Scenario: Using bridges
    Given I capture all network traffic
    When the network is plugged
    And the Tor Launcher autostarts
    And I configure some Bridge pluggable transports in Tor Launcher
    Then Tor is ready
    And available upgrades have been checked
    And all Internet traffic has only flowed through the configured pluggable transports

  Scenario: Using obfs3 pluggable transports
    Given I capture all network traffic
    When the network is plugged
    And the Tor Launcher autostarts
    And I configure some obfs3 pluggable transports in Tor Launcher
    Then Tor is ready
    And available upgrades have been checked
    And all Internet traffic has only flowed through the configured pluggable transports
