@product
Feature: System memory erasure on shutdown
  As a Tails user
  when I shutdown Tails
  I want the system memory to be free from sensitive data.

  Scenario: Anti-test: no memory erasure
    Given a computer
    And the computer has 8 GiB of RAM
    And I set Tails to boot with options "debug=wipemem"
    And I start Tails from DVD with network unplugged and I login
    Then at least 8 GiB of RAM was detected
    And process "memlockd" is running
    And process "udev-watchdog" is running
    And udev-watchdog is monitoring the correct device
    When I fill the guest's memory with a known pattern without verifying
    And I reboot without wiping the memory
    And I stop the boot at the bootloader menu
    Then I find many patterns in the guest's memory

  Scenario: Memory erasure
    Given a computer
    And the computer has 8 GiB of RAM
    And I set Tails to boot with options "debug=wipemem"
    And I start Tails from DVD with network unplugged and I login
    Then at least 8 GiB of RAM was detected
    And process "memlockd" is running
    And process "udev-watchdog" is running
    And udev-watchdog is monitoring the correct device
    When I fill the guest's memory with a known pattern
    And I shutdown and wait for Tails to finish wiping the memory
    Then I find very few patterns in the guest's memory
