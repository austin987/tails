#10720: Tails Installer freezes on Jenkins
@product @fragile
Feature: Upgrading an old Tails USB installation
  As a Tails user
  If I have an old versoin of Tails installed on a USB device
  and the USB device has a persistent partition
  I want to upgrade Tails on it
  and keep my persistent partition in the process

  # An issue with this feature is that scenarios depend on each
  # other. When editing this feature, make sure you understand these
  # dependencies (which are documented below).

  Scenario: Try to "Upgrade from ISO" Tails to a pristine USB drive
    Given a computer
    And I setup a filesystem share containing the Tails ISO
    And I start Tails from DVD with network unplugged and I login
    And I temporarily create a 4 GiB disk named "pristine"
    And I plug USB drive "pristine"
    And I start Tails Installer in "Upgrade from ISO" mode
    Then a suitable USB device is not found
    And I am told that the destination device cannot be upgraded

  Scenario: Try to "Clone & Upgrade" Tails to a pristine USB drive
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 4 GiB disk named "pristine"
    And I plug USB drive "pristine"
    And I start Tails Installer in "Clone & Upgrade" mode
    Then a suitable USB device is not found
    And I am told that the destination device cannot be upgraded

  Scenario: Try to "Upgrade from ISO" Tails to a USB drive with GPT and a FAT partition
    Given a computer
    And I setup a filesystem share containing the Tails ISO
    And I start Tails from DVD with network unplugged and I login
    And I temporarily create a 4 GiB disk named "gptfat"
    And I create a gpt partition with a vfat filesystem on disk "gptfat"
    And I plug USB drive "gptfat"
    And I start Tails Installer in "Upgrade from ISO" mode
    Then a suitable USB device is not found
    And I am told that the destination device cannot be upgraded

  Scenario: Try to "Clone & Upgrade" Tails to a USB drive with GPT and a FAT partition
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 4 GiB disk named "gptfat"
    And I create a gpt partition with a vfat filesystem on disk "gptfat"
    And I plug USB drive "gptfat"
    And I start Tails Installer in "Upgrade from ISO" mode
    Then a suitable USB device is not found
    And I am told that the destination device cannot be upgraded

  Scenario: Installing an old version of Tails to a pristine USB drive
    Given a computer
    And the computer is set to boot from the old Tails DVD
    And the network is unplugged
    And I start the computer
    When the computer boots Tails
    And I log in to a new session
    And all notifications have disappeared
    And I create a 4 GiB disk named "old"
    And I plug USB drive "old"
    And I "Clone & Install" Tails to USB drive "old"
    Then the running Tails is installed on USB drive "old"
    But there is no persistence partition on USB drive "old"
    And I unplug USB drive "old"

  # Depends on scenario: Installing an old version of Tails to a pristine USB drive
  Scenario: Creating a persistent partition with the old Tails USB installation
    Given a computer
    And I start Tails from USB drive "old" with network unplugged and I login
    Then Tails is running from USB drive "old"
    And I create a persistent partition
    And I take note of which persistence presets are available
    Then a Tails persistence partition exists on USB drive "old"
    And I shutdown Tails and wait for the computer to power off

  # Depends on scenario: Creating a persistent partition with the old Tails USB installation
  Scenario: Writing files to a read/write-enabled persistent partition with the old Tails USB installation
    Given a computer
    And I start Tails from USB drive "old" with network unplugged and I login with persistence enabled
    Then Tails is running from USB drive "old"
    And all persistence presets are enabled
    And I write some files expected to persist
    And all persistent filesystems have safe access rights
    And all persistence configuration files have safe access rights
    And all persistent directories from the old Tails version have safe access rights
    And I take note of which persistence presets are available
    And I shutdown Tails and wait for the computer to power off
    # XXX: how does guestfs work vs snapshots?
    Then only the expected files are present on the persistence partition on USB drive "old"

  # Depends on scenario: Writing files to a read/write-enabled persistent partition with the old Tails USB installation
  Scenario: Upgrading an old Tails USB installation from a Tails DVD
    Given I have started Tails from DVD without network and logged in
    And I clone USB drive "old" to a new USB drive "to_upgrade"
    And I plug USB drive "to_upgrade"
    When I "Clone & Upgrade" Tails to USB drive "to_upgrade"
    Then the running Tails is installed on USB drive "to_upgrade"
    And I unplug USB drive "to_upgrade"

  # Depends on scenario: Upgrading an old Tails USB installation from a Tails DVD
  Scenario: Booting Tails from a USB drive upgraded from DVD with persistence enabled
    Given a computer
    And I start Tails from USB drive "to_upgrade" with network unplugged and I login with persistence enabled
    Then all persistence presets from the old Tails version are enabled
    And Tails is running from USB drive "to_upgrade"
    And the boot device has safe access rights
    And the expected persistent files created with the old Tails version are present in the filesystem
    And all persistent directories from the old Tails version have safe access rights

  # Depends on scenario: Writing files to a read/write-enabled persistent partition with the old Tails USB installation
  Scenario: Upgrading an old Tails USB installation from another Tails USB drive
    Given I have started Tails without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen
    And I log in to a new session
    And I clone USB drive "old" to a new USB drive "to_upgrade"
    And I plug USB drive "to_upgrade"
    When I "Clone & Upgrade" Tails to USB drive "to_upgrade"
    Then the running Tails is installed on USB drive "to_upgrade"
    And I unplug USB drive "to_upgrade"
    And I unplug USB drive "__internal"

  # Depends on scenario: Upgrading an old Tails USB installation from another Tails USB drive
  Scenario: Booting Tails from a USB drive upgraded from USB with persistence enabled
    Given a computer
    And I start Tails from USB drive "to_upgrade" with network unplugged and I login with persistence enabled
    Then all persistence presets from the old Tails version are enabled
    And Tails is running from USB drive "to_upgrade"
    And the boot device has safe access rights
    And the expected persistent files created with the old Tails version are present in the filesystem
    And all persistent directories from the old Tails version have safe access rights

  # Depends on scenario: Writing files to a read/write-enabled persistent partition with the old Tails USB installation
  Scenario: Upgrading an old Tails USB installation from an ISO image, running on the old version
    Given a computer
    And I clone USB drive "old" to a new USB drive "to_upgrade"
    And I setup a filesystem share containing the Tails ISO
    When I start Tails from USB drive "old" with network unplugged and I login
    And I plug USB drive "to_upgrade"
    And I do a "Upgrade from ISO" on USB drive "to_upgrade"
    Then the ISO's Tails is installed on USB drive "to_upgrade"
    And I unplug USB drive "to_upgrade"

  # Depends on scenario: Writing files to a read/write-enabled persistent partition with the old Tails USB installation
  Scenario: Upgrading an old Tails USB installation from an ISO image, running on the new version
    Given a computer
    And I clone USB drive "old" to a new USB drive "to_upgrade"
    And I setup a filesystem share containing the Tails ISO
    And I start Tails from DVD with network unplugged and I login
    And I plug USB drive "to_upgrade"
    And I do a "Upgrade from ISO" on USB drive "to_upgrade"
    Then the ISO's Tails is installed on USB drive "to_upgrade"
    And I unplug USB drive "to_upgrade"

  # Depends on scenario: Upgrading an old Tails USB installation from an ISO image, running on the new version
  Scenario: Booting a USB drive upgraded from ISO with persistence enabled
    Given a computer
    And I start Tails from USB drive "to_upgrade" with network unplugged and I login with persistence enabled
    Then all persistence presets from the old Tails version are enabled
    And Tails is running from USB drive "to_upgrade"
    And the boot device has safe access rights
    And the expected persistent files created with the old Tails version are present in the filesystem
    And all persistent directories from the old Tails version have safe access rights
