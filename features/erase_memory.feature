@product
Feature: System memory erasure on shutdown
  As a Tails user
  when I shutdown Tails
  I want the system memory to be free from sensitive data.

  Scenario: Anti-test: no memory erasure on a modern computer
    Given a computer
    And the computer is a modern 64-bit system
    And the computer has 8 GiB of RAM
    And I set Tails to boot with options "debug=wipemem"
    And I start Tails from DVD with network unplugged and I login
    Then the PAE kernel is running
    And at least 8 GiB of RAM was detected
    And process "memlockd" is running
    And process "udev-watchdog" is running
    When I fill the guest's memory with a known pattern without verifying
    And I reboot without wiping the memory
    Then I find many patterns in the guest's memory

  Scenario: Memory erasure on a modern computer
    Given a computer
    And the computer is a modern 64-bit system
    And the computer has 8 GiB of RAM
    And I set Tails to boot with options "debug=wipemem"
    And I start Tails from DVD with network unplugged and I login
    Then the PAE kernel is running
    And at least 8 GiB of RAM was detected
    And process "memlockd" is running
    And process "udev-watchdog" is running
    When I fill the guest's memory with a known pattern
    And I shutdown and wait for Tails to finish wiping the memory
    Then I find very few patterns in the guest's memory

  Scenario: Anti-test: no memory erasure on an old computer
    Given a computer
    And the computer is an old pentium without the PAE extension
    And the computer has 8 GiB of RAM
    And I set Tails to boot with options "debug=wipemem"
    And I start Tails from DVD with network unplugged and I login
    Then the non-PAE kernel is running
    And at least 3500 MiB of RAM was detected
    And process "memlockd" is running
    And process "udev-watchdog" is running
    When I fill the guest's memory with a known pattern without verifying
    And I reboot without wiping the memory
    Then I find many patterns in the guest's memory

  Scenario: Memory erasure on an old computer
    Given a computer
    And the computer is an old pentium without the PAE extension
    And the computer has 8 GiB of RAM
    And I set Tails to boot with options "debug=wipemem"
    And I start Tails from DVD with network unplugged and I login
    And the non-PAE kernel is running
    And at least 3500 MiB of RAM was detected
    And process "memlockd" is running
    And process "udev-watchdog" is running
    When I fill the guest's memory with a known pattern
    And I shutdown and wait for Tails to finish wiping the memory
    Then I find very few patterns in the guest's memory
