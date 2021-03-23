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
