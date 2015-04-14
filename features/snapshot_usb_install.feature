@product
Feature: Installing Tails to a USB drive, upgrading it, and using persistence
  As a Tails user
  I may want to install Tails to a USB drive
  and upgrade it to new Tails versions
  and use persistence

  Scenario: Booting Tails from a USB drive without a persistent partition
    Given I reach the "usb-install" checkpoint
    When I log in to a new session
    Then Tails seems to have booted normally
    And Tails is running from USB drive "current"
    And the persistent Tor Browser directory does not exist
    And there is no persistence partition on USB drive "current"

  Scenario: Booting Tails from a USB drive with a disabled persistent partition
    Given I reach the "usb-install-with-persistence" checkpoint
    When I log in to a new session
    Then Tails seems to have booted normally
    And Tails is running from USB drive "current"
    And persistence is disabled
    But a Tails persistence partition with password "asdf" exists on USB drive "current"

  Scenario: Booting Tails from a USB drive with an enabled persistent partition
    Given I reach the "usb-install-with-persistence" checkpoint
    When I enable persistence with password "asdf"
    And I log in to a new session
    Then Tails seems to have booted normally
    And Tails is running from USB drive "current"
    And all persistence presets are enabled
    And all persistent directories have safe access rights
