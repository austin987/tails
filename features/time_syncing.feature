@product @check_tor_leaks
Feature: Time syncing
  As a Tails user
  I want Tor to work properly
  And for that I need a reasonably accurate system clock

  Background:
    Given Tails has booted from DVD without network and logged in

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

  Scenario: Skip the background's snapshot, boot with a hardware clock set way in the past and make sure that Tails sets the clock to the build date
    Given a computer
    And the network is unplugged
    And the hardware clock is set to "01 Jan 2000 12:34:56"
    And I start the computer
    And the computer boots Tails
    Then the system clock is just past Tails' build date
