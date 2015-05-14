@product
Feature: Using Tails with Tor pluggable transports
  As a Tails user
  I want to circumvent censorship of Tor by using Tor pluggable transports
  And avoid connecting directly to the Tor Network

  Background:
    Given Tails has booted from DVD without network and stopped at Tails Greeter's login screen
    And I enable more Tails Greeter options
    And I enable the specific Tor configuration option
    And I log in to a new session
    And the Tails desktop is ready
    And I capture all network traffic
    When the network is plugged
    Then the Tor Launcher autostarts

  Scenario: Using bridges
    When I configure some Bridge pluggable transports in Tor Launcher
    Then Tor is ready
    And available upgrades have been checked
    And all Internet traffic has only flowed through the configured pluggable transports

  Scenario: Using obfs2 pluggable transports
    When I configure some obfs2 pluggable transports in Tor Launcher
    Then Tor is ready
    And available upgrades have been checked
    And all Internet traffic has only flowed through the configured pluggable transports

  Scenario: Using obfs3 pluggable transports
    When I configure some obfs3 pluggable transports in Tor Launcher
    Then Tor is ready
    And available upgrades have been checked
    And all Internet traffic has only flowed through the configured pluggable transports

  Scenario: Using obfs4 pluggable transports
    When I configure some obfs4 pluggable transports in Tor Launcher
    Then Tor is ready
    And available upgrades have been checked
    And all Internet traffic has only flowed through the configured pluggable transports
