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

  Scenario: The system time is not synced to the hardware clock
    When I bump the system time with "-15 days"
    And I warm reboot the computer
    And the computer reboots Tails
    Then Tails' hardware clock is close to the host system's time

  Scenario: Anti-test: Changes to the hardware clock are kept when rebooting
    When I bump the hardware clock's time with "-15 days"
    And I warm reboot the computer
    And the computer reboots Tails
    Then the hardware clock is still off by "-15 days"

#  Scenario: Clock vs Tor consensus' valid-{after,until} etc.

  Scenario: Create a new snapshot to the same state (w.r.t. Sikuli steps) as the Background except we're now in bridge mode
    Given a computer
    And the network is unplugged
    And I start the computer
    And the computer boots Tails
    And I enable more Tails Greeter options
    And I enable the specific Tor configuration option
    And I log in to a new session
    And the Tails desktop is ready
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

  Scenario: Skip the background snapshot, boot with a hardware clock set way in the past and make sure that Tails sets the clock to the build date
    Given a computer
    And the network is unplugged
    And the hardware clock is set to "01 Jan 2000 12:34:56"
    And I start the computer
    And the computer boots Tails
    Then the system clock is just past Tails' build date
