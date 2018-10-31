@product
Feature: Installing Tails to a USB drive
  As a Tails user
  I want to install Tails to a suitable USB drive

  Scenario: Try installing Tails to a too small USB drive without partition table
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 4500 MiB disk named "too-small-device"
    And I start Tails Installer
    But a suitable USB device is not found
    And no USB drive is selected
    When I plug USB drive "too-small-device"
    Then I am told by Tails Installer that the destination device "is too small"
    And no USB drive is selected
    When I unplug USB drive "too-small-device"
    And I temporarily create a 7200 MiB disk named "big-enough"
    And I plug USB drive "big-enough"
    Then the "big-enough" USB drive is selected

  Scenario: Try installing Tails to a too small USB drive with GPT and a FAT partition
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 4 GiB disk named "gptfat"
    And I create a gpt partition with a vfat filesystem on disk "gptfat"
    And I plug USB drive "gptfat"
    When I start Tails Installer
    Then I am told by Tails Installer that the destination device "is too small"

  Scenario: Detecting when a target USB drive is inserted or removed
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 7200 MiB disk named "temp"
    And I start Tails Installer
    But a suitable USB device is not found
    When I plug USB drive "temp"
    Then the "temp" USB drive is selected
    When I unplug USB drive "temp"
    Then a suitable USB device is not found

  Scenario: Installing Tails to a used USB drive
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 7200 MiB disk named "install"
    And I create a gpt partition with a vfat filesystem on disk "install"
    And I plug USB drive "install"
    And I install Tails to USB drive "install" by cloning
    Then the running Tails is installed on USB drive "install"
    But there is no persistence partition on USB drive "install"

  Scenario: Installing Tails to a pristine USB drive
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 7200 MiB disk named "install"
    And I plug USB drive "install"
    And I install Tails to USB drive "install" by cloning
    Then the running Tails is installed on USB drive "install"
    But there is no persistence partition on USB drive "install"

  Scenario: Re-installing Tails over an existing USB installation with a persistent partition
    # We reach this first checkpoint only to ensure that the ' __internal' disk has reached the state (Tails installed + persistent partition set up) we need before we clone it below.
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    Given I have started Tails from DVD without network and logged in
    And I clone USB drive "__internal" to a temporary USB drive "install"
    And I plug USB drive "install"
    When I reinstall Tails to USB drive "install" by cloning
    Then the running Tails is installed on USB drive "install"
    And there is no persistence partition on USB drive "install"

  Scenario: Booting Tails from a USB drive without a persistent partition and creating one
    Given I have started Tails without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen
    And I log in to a new session
    When I create a persistent partition
    Then a Tails persistence partition exists on USB drive "__internal"

  Scenario: Booting Tails from a USB drive without a persistent partition
    Given I have started Tails without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen
    When I log in to a new session
    Then Tails is running from USB drive "__internal"
    And the persistent Tor Browser directory does not exist
    And there is no persistence partition on USB drive "__internal"

  #13459
  @fragile
  Scenario: Booting Tails from a USB drive in UEFI mode
    Given I have started Tails without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen
    Then I power off the computer
    Given the computer is set to boot in UEFI mode
    When I start Tails from USB drive "__internal" with network unplugged and I login
    Then the boot device has safe access rights
    And Tails is running from USB drive "__internal"
    And the boot device has safe access rights
    And Tails has started in UEFI mode

  Scenario: Installing Tails to a USB drive with an MBR partition table but no partitions, and making sure that it boots
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 7200 MiB disk named "mbr"
    And I create a msdos label on disk "mbr"
    And I plug USB drive "mbr"
    And I install Tails to USB drive "mbr" by cloning
    Then the running Tails is installed on USB drive "mbr"
    But there is no persistence partition on USB drive "mbr"
    When I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "mbr" with network unplugged and I login
    Then Tails is running from USB drive "mbr"
    And the boot device has safe access rights
    And there is no persistence partition on USB drive "mbr"

  Scenario: Writing a Tails isohybrid to a USB drive and booting it, then installing Tails on top of it using Tails Installer, and it still boots
    Given a computer
    And I temporarily create a 7200 MiB disk named "isohybrid"
    And I write the Tails ISO image to disk "isohybrid"
    And I start Tails from USB drive "isohybrid" with network unplugged and I login
    Then Tails is running from USB drive "isohybrid"
    When I shutdown Tails and wait for the computer to power off
    And I start Tails from DVD with network unplugged and I login
    And I install Tails to USB drive "isohybrid" by cloning
    Then the running Tails is installed on USB drive "isohybrid"
    But there is no persistence partition on USB drive "isohybrid"
    When I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "isohybrid" with network unplugged and I login
    Then Tails is running from USB drive "isohybrid"
    And the boot device has safe access rights
    And there is no persistence partition on USB drive "isohybrid"
