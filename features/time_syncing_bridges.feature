@product @check_tor_leaks
Feature: Time syncing with Tor pluggable transports
  As a Tails user
  I want Tor to work properly in bridge mode
  And for that I need a reasonably accurate system clock

  Background:
    Given Tails has booted from DVD without network and logged in with bridge mode enabled

  Scenario: Clock with host's time in bridge mode
    When the network is plugged
    And the Tor Launcher autostarts
    And I configure some Bridge pluggable transports in Tor Launcher
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

  Scenario: Clock is one day in the past in bridge mode
    When I bump the system time with "-1 day"
    And the network is plugged
    And the Tor Launcher autostarts
    And I configure some Bridge pluggable transports in Tor Launcher
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

  Scenario: Clock way in the past in bridge mode
    When I set the system time to "01 Jan 2000 12:34:56"
    And the network is plugged
    And the Tor Launcher autostarts
    And I configure some Bridge pluggable transports in Tor Launcher
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

  Scenario: Clock is one day in the future in bridge mode
    When I bump the system time with "+1 day"
    And the network is plugged
    And the Tor Launcher autostarts
    And I configure some Bridge pluggable transports in Tor Launcher
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

  Scenario: Clock way in the future in bridge mode
    When I set the system time to "01 Jan 2020 12:34:56"
    And the network is plugged
    And the Tor Launcher autostarts
    And I configure some Bridge pluggable transports in Tor Launcher
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect
