@product
Feature: Installing Tails to a USB drive
  As a Tails user
  I want to install Tails to a suitable USB drive

  Scenario: Try installing Tails to a too small USB drive
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 2 GiB disk named "too-small-device"
    And I start Tails Installer in "Clone & Install" mode
    But a suitable USB device is not found
    When I plug USB drive "too-small-device"
    Then Tails Installer detects that a device is too small
    And a suitable USB device is not found
    When I unplug USB drive "too-small-device"
    And I create a 4 GiB disk named "big-enough"
    And I plug USB drive "big-enough"
    Then the "big-enough" USB drive is selected

  Scenario: Detecting when a target USB drive is inserted or removed
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 4 GiB disk named "temp"
    And I start Tails Installer in "Clone & Install" mode
    But a suitable USB device is not found
    When I plug USB drive "temp"
    Then the "temp" USB drive is selected
    When I unplug USB drive "temp"
    Then no USB drive is selected
    And a suitable USB device is not found

  #10720: Tails Installer freezes on Jenkins
  @fragile
  Scenario: Installing Tails to a pristine USB drive
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 4 GiB disk named "install"
    And I plug USB drive "install"
    And I "Clone & Install" Tails to USB drive "install"
    Then the running Tails is installed on USB drive "install"
    But there is no persistence partition on USB drive "install"

  #10720: Tails Installer freezes on Jenkins
  @fragile
  Scenario: Booting Tails from a USB drive without a persistent partition and creating one
    Given I have started Tails without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen
    And I log in to a new session
    When I create a persistent partition
    Then a Tails persistence partition exists on USB drive "__internal"

  #10720: Tails Installer freezes on Jenkins
  @fragile
  Scenario: Booting Tails from a USB drive without a persistent partition
    Given I have started Tails without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen
    When I log in to a new session
    Then Tails is running from USB drive "__internal"
    And the persistent Tor Browser directory does not exist
    And there is no persistence partition on USB drive "__internal"

  #10720: Tails Installer freezes on Jenkins
  #11583
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

  #10720: Tails Installer freezes on Jenkins
  @fragile
  Scenario: Installing Tails to a USB drive with an MBR partition table but no partitions, and making sure that it boots
    Given I have started Tails from DVD without network and logged in
    And I temporarily create a 4 GiB disk named "mbr"
    And I create a msdos label on disk "mbr"
    And I plug USB drive "mbr"
    And I "Clone & Install" Tails to USB drive "mbr"
    Then the running Tails is installed on USB drive "mbr"
    But there is no persistence partition on USB drive "mbr"
    When I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "mbr" with network unplugged and I login
    Then Tails is running from USB drive "mbr"
    And the boot device has safe access rights
    And there is no persistence partition on USB drive "mbr"

  #10720: Tails Installer freezes on Jenkins
  @fragile
  Scenario: Cat:ing a Tails isohybrid to a USB drive and booting it, then trying to upgrading it but ending up having to do a fresh installation, which boots
    Given a computer
    And I temporarily create a 4 GiB disk named "isohybrid"
    And I cat an ISO of the Tails image to disk "isohybrid"
    And I start Tails from USB drive "isohybrid" with network unplugged and I login
    Then Tails is running from USB drive "isohybrid"
    When I shutdown Tails and wait for the computer to power off
    And I start Tails from DVD with network unplugged and I login
    And I try a "Clone & Upgrade" Tails to USB drive "isohybrid"
    Then I am suggested to do a "Clone & Install"
    When I kill the process "tails-installer"
    And I "Clone & Install" Tails to USB drive "isohybrid"
    Then the running Tails is installed on USB drive "isohybrid"
    But there is no persistence partition on USB drive "isohybrid"
    When I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "isohybrid" with network unplugged and I login
    Then Tails is running from USB drive "isohybrid"
    And the boot device has safe access rights
    And there is no persistence partition on USB drive "isohybrid"
