#11589
@product @fragile
Feature: Using Tails with Tor bridges and pluggable transports
  As a Tails user
  I want to circumvent censorship of Tor by using Tor bridges and pluggable transports
  And avoid connecting directly to the Tor Network

  Background:
    Given I have started Tails from DVD without network and logged in
    And I capture all network traffic
    When the network is plugged
    Then the Tor Connection Assistant autostarts

  Scenario: Using normal bridges
    When I configure some normal bridges in the Tor Connection Assistant
    Then Tor is ready
    And available upgrades have been checked
    And all Internet traffic has only flowed through the configured bridges

  Scenario: Using obfs4 pluggable transports
    When I configure some obfs4 bridges in the Tor Connection Assistant
    Then Tor is ready
    And available upgrades have been checked
    And all Internet traffic has only flowed through the configured bridges

  Scenario: Fall back to default bridges if failing to connect directly to the Tor network
    Given the Tor network is blocked
    When I configure a direct connection in the Tor Connection Assistant
    Then Tor is ready
    And available upgrades have been checked
    And Tor is configured to use the default bridges

  Scenario: TCA can reconnect after a connection failure
    Given the Tor network and default bridges are blocked
    When I try to configure a direct connection in the Tor Connection Assistant
    Then the Tor Connection Assistant reports that it failed to connect
    # TCA does not have a simple "retry" so we restart it
    And I close the Tor Connection Assistant
    # Before we unblock we must stop Tor from retrying, otherwise the
    # above first try might succeed, which isn't what we expect or
    # want to test here.
    And I set DisableNetwork=1 over Tor's control port
    Given the Tor network and default bridges are unblocked
    And I start "Tor Connection" via GNOME Activities Overview
    When I configure a direct connection in the Tor Connection Assistant
    Then Tor is ready
    And available upgrades have been checked
