@product @check_tor_leaks
Feature: Time syncing
  As a Tails user
  I want Tor to work properly
  And for that I need a reasonably accurate system clock

  Scenario: Clock with host's time
    Given I have started Tails from DVD without network and logged in
    When the network is plugged
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

  #11589
  @fragile
  Scenario: Clock with host's time in bridge mode
    Given I have started Tails from DVD without network and logged in with bridge mode enabled
    When the network is plugged
    And the Tor Launcher autostarts
    And I configure some bridge pluggable transports in Tor Launcher
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

  #11589
  @fragile
  Scenario: Clock is one day in the future in bridge mode
    Given I have started Tails from DVD without network and logged in with bridge mode enabled
    When I bump the system time with "+1 day"
    And the network is plugged
    And the Tor Launcher autostarts
    And I configure some bridge pluggable transports in Tor Launcher
    And Tor is ready
    Then Tails clock is less than 5 minutes incorrect

  Scenario: The system time is not synced to the hardware clock
    Given I have started Tails from DVD without network and logged in
    When I bump the system time with "-15 days"
    And I warm reboot the computer
    And the computer reboots Tails
    Then Tails' hardware clock is close to the host system's time

  Scenario: Anti-test: Changes to the hardware clock are kept when rebooting
    Given I have started Tails from DVD without network and logged in
    When I bump the hardware clock's time with "-15 days"
    And I warm reboot the computer
    And the computer reboots Tails
    Then the hardware clock is still off by "-15 days"

  Scenario: Boot with a hardware clock set way in the past and make sure that Tails sets the clock to the source date
    Given a computer
    And the network is unplugged
    And the hardware clock is set to "01 Jan 2000 12:34:56"
    And I start the computer
    And the computer boots Tails
    Then the system clock is just past Tails' source date
