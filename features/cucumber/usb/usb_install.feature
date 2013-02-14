Feature: Installing Tails to a USB drive, upgrading it, and using persistence
  As a Tails user
  I may want to install Tails to a USB drive
  and upgrade it to new Tails versions
  and use persistence

  Background:
    Given I restore the background snapshot if it exists
    And a freshly started Tails
    And the network is unplugged
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And I create a new 4 GiB USB drive named "A"
    And I plug USB drive "A"
    And I "Clone & Install" Tails to USB drive "A"
    And I unplug USB drive "A"
    And I save the background snapshot if it does not exist

  Scenario: Tails boot from USB drive without persistent partition
    When I boot Tails from USB drive "A"
    And the network is unplugged
    And I log in to a new session
    Then Tails seems to have booted normally
    And Tails is running from a USB drive

  Scenario: Creating a persistent partition
    When I boot Tails from USB drive "A"
    And the network is unplugged
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And I create a persistent partition with password "asdf"
    And I shutdown Tails
    Then a Tails persistence partition exists on USB drive "A"

  Scenario: Writing files to read/write-enabled persistent partition
    When I boot Tails from USB drive "A"
    And the network is unplugged
    And I enable persistence with password "asdf"
    And I log in to a new session
    And persistence has been enabled
    And I write some files expected to persist
    And I shutdown Tails
    Then only the expected files should persist on USB drive "A"

  Scenario: Writing files to read-only-enabled persistent partition
    When I boot Tails from USB drive "A"
    And the network is unplugged
    And I enable read-only persistence with password "asdf"
    And I log in to a new session
    And persistence has been enabled
    And I write some files not expected to persist
    And I remove some files expected to persist
    And I shutdown Tails
    Then only the expected files should persist on USB drive "A"

  Scenario: Upgrading a Tails USB from a Tails DVD and booting it
    When I plug USB drive "A"
    And I "Clone & Upgrade" Tails to USB drive "A"
    And I unplug USB drive "A"
    And I boot Tails from USB drive "A"
    And the network is unplugged
    And I enable read-only persistence with password "asdf"
    And I log in to a new session
    Then Tails seems to have booted normally
    And persistence has been enabled
    And Tails is running from a USB drive

  Scenario: Upgrading a Tails USB from another Tails USB and booting it
    Given I clone USB drive "A" to a new USB drive "B"
    When I boot Tails from USB drive "A"
    And the network is unplugged
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And I plug USB drive "B"
    And I "Clone & Upgrade" Tails to USB drive "B"
    And I unplug USB drive "B"
    And I unplug USB drive "A"
    And I boot Tails from USB drive "B"
    And the network is unplugged
    And I enable read-only persistence with password "asdf"
    And I log in to a new session
    Then Tails seems to have booted normally
    And persistence has been enabled
    And Tails is running from a USB drive

  Scenario: Upgrading a Tails USB from an ISO image and booting it
    Given I boot Tails from DVD with a Tails ISO image available
    And the network is unplugged
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    When I plug USB drive "A"
    And I do a "Upgrade from ISO" on USB drive "A"
    And I unplug USB drive "A"
    And I boot Tails from USB drive "A"
    And the network is unplugged
    And I enable read-only persistence with password "asdf"
    And I log in to a new session
    Then Tails seems to have booted normally
    And persistence has been enabled
    And Tails is running from a USB drive
