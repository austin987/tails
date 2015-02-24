@product @check_tor_leaks
Feature: Time syncing
  As a Tails user
  I want Tor to work properly
  And for that I need a reasonably accurate system clock

  Background:
    Given a computer
    And I start Tails from DVD with network unplugged and I login
    And I save the state so the background can be restored next scenario

  Scenario: Clock with host's time
    When the network is plugged
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

  Scenario: Clock is one day in the past
    When I bump the system time with "-1 day"
    And the network is plugged
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

  Scenario: Clock way in the past
    When I set the system time to "01 Jan 2000 12:34:56"
    And the network is plugged
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

  Scenario: Clock is one day in the future
    When I bump the system time with "+1 day"
    And the network is plugged
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

  Scenario: Clock way in the future
    When I set the system time to "01 Jan 2020 12:34:56"
    And the network is plugged
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

#  Scenario: Clock vs Tor consensus' valid-{after,until} etc.

  Scenario: Create a new snapshot to the same state (w.r.t. Sikuli steps) as the Background except we're now in bridge mode
    Given a computer
    And the network is unplugged
    And I start the computer
    And the computer boots Tails
    And I enable more Tails Greeter options
    And I enable the specific Tor configuration option
    And I log in to a new session
    And GNOME has started
    And I save the state so the background can be restored next scenario

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
