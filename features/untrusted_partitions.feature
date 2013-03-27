@product
Feature: Untrusted partitions
  As a Tails user
  I don't want to touch other media than the one Tails runs from

  # XXX: For some strange reason plugging sata drives below result in
  # SMART errors for the drives inside Tails, so we stick with ide.

  Scenario: Tails does not boot from live systems stored on hard drives
    Given a computer
    And I create a 1 GiB disk named "live_hd"
    And I cat an ISO hybrid of the Tails image to disk "live_hd"
    And I plug ide drive "live_hd"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    Then drive "live_hd" is detected by Tails
    And drive "live_hd" is not mounted

  Scenario: Booting Tails does not automount untrusted ext2 partitions
    Given a computer
    And I create a 100 MiB disk named "gpt_ext2"
    And I create a gpt label on disk "gpt_ext2"
    And I create a ext2 filesystem on disk "gpt_ext2"
    And I plug ide drive "gpt_ext2"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    Then drive "gpt_ext2" is detected by Tails
    And drive "gpt_ext2" is not mounted

  Scenario: Booting Tails does not automount untrusted fat32 partitions
    Given a computer
    And I create a 100 MiB disk named "msdos_fat32"
    And I create a msdos label on disk "msdos_fat32"
    And I create a fat32 filesystem on disk "msdos_fat32"
    And I plug ide drive "msdos_fat32"
    And the network is unplugged
    When I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    Then drive "msdos_fat32" is detected by Tails
    And drive "msdos_fat32" is not mounted
