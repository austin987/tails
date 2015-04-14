@product
Feature: Installing Tails to a USB drive, upgrading it, and using persistence
  As a Tails user
  I may want to install Tails to a USB drive
  and upgrade it to new Tails versions
  and use persistence

  Scenario: Create a snapshot at Tails Greeter's login screen when booting Tails from a USB drive without a persistent partition
    Given a computer
    When I start Tails from DVD with network unplugged and I login
    And I create a 4 GiB disk named "current"
    And I plug USB drive "current"
    And I "Clone & Install" Tails to USB drive "current"
    Then the running Tails is installed on USB drive "current"
    But there is no persistence partition on USB drive "current"
    When I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "current" with network unplugged
    Then the boot device has safe access rights
    And Tails is running from USB drive "current"
    And there is no persistence partition on USB drive "current"
    And I save the snapshot "usb-install"

  Scenario: Create a snapshot at Tails Greeter's login screen when booting Tails from a USB drive with a persistent partition
    Given a computer
    When I restore the snapshot "usb-install"
    And I log in to a new session
    And I create a persistent partition with password "asdf"
    Then a Tails persistence partition with password "asdf" exists on USB drive "current"
    When I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "current" with network unplugged
    Then the boot device has safe access rights
    And Tails is running from USB drive "current"
    And I save the snapshot "usb-install-with-persistence"

  Scenario: Booting Tails from a USB drive without a persistent partition
    Given a computer
    When I restore the snapshot "usb-install"
    And I log in to a new session
    Then Tails seems to have booted normally
    And Tails is running from USB drive "current"
    And the persistent Tor Browser directory does not exist
    And there is no persistence partition on USB drive "current"

  Scenario: Booting Tails from a USB drive with a disabled persistent partition
    Given a computer
    When I restore the snapshot "usb-install-with-persistence"
    And I log in to a new session
    Then Tails seems to have booted normally
    And Tails is running from USB drive "current"
    And persistence is disabled
    But a Tails persistence partition with password "asdf" exists on USB drive "current"

  Scenario: Booting Tails from a USB drive with an enabled persistent partition
    Given a computer
    When I restore the snapshot "usb-install-with-persistence"
    And I enable persistence with password "asdf"
    And I log in to a new session
    Then Tails seems to have booted normally
    And Tails is running from USB drive "current"
    And all persistence presets are enabled
    And all persistent directories have safe access rights
