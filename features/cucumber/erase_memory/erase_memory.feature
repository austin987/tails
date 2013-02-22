Feature: System memory erasure on shutdown
  As a Tails user
  when I shutdown Tails
  I want the system memory to be free from sensitive data.

  Background:
    Given a computer
    And I set Tails to boot with options "debug=wipemem"
    And the network is unplugged
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And process "memlockd" is running
    And process "udev-watchdog" is running

  Scenario: Memory must be erased on shutdown.
    When I fill the guest's memory with a known pattern
    And I dump the guest's memory into file "before_wipe.dump"
    And I shutdown Tails and let it wipe the memory
    And I dump the guest's memory into file "after_wipe.dump"
    Then I find at least 10000000 patterns in the dump "before_wipe.dump"
    And I find at most 1000 patterns in the dump "after_wipe.dump"
