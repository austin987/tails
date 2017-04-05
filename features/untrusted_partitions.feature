@product
Feature: Untrusted partitions
  As a Tails user
  I don't want to touch other media than the one Tails runs from

  Scenario: Tails will not enable disk swap
    Given a computer
    And I temporarily create a 100 MiB disk named "swap"
    And I create a gpt swap partition on disk "swap"
    And I plug sata drive "swap"
    When I start Tails with network unplugged and I login
    Then a "swap" partition was detected by Tails on drive "swap"
    But Tails has no disk swap enabled

  Scenario: Tails will detect LUKS-encrypted GPT partitions labeled "TailsData" stored on USB drives as persistence volumes when the removable flag is set
    Given a computer
    And I temporarily create a 100 MiB disk named "fake_TailsData"
    And I create a gpt partition labeled "TailsData" with an ext4 filesystem encrypted with password "asdf" on disk "fake_TailsData"
    And I plug removable usb drive "fake_TailsData"
    When I start the computer
    And the computer boots Tails
    Then drive "fake_TailsData" is detected by Tails
    And Tails Greeter has detected a persistence partition

  Scenario: Tails will not detect LUKS-encrypted GPT partitions labeled "TailsData" stored on USB drives as persistence volumes when the removable flag is unset
    Given a computer
    And I temporarily create a 100 MiB disk named "fake_TailsData"
    And I create a gpt partition labeled "TailsData" with an ext4 filesystem encrypted with password "asdf" on disk "fake_TailsData"
    And I plug non-removable usb drive "fake_TailsData"
    When I start the computer
    And the computer boots Tails
    Then drive "fake_TailsData" is detected by Tails
    And Tails Greeter has not detected a persistence partition

  Scenario: Tails will not detect LUKS-encrypted GPT partitions labeled "TailsData" stored on local hard drives as persistence volumes
    Given a computer
    And I temporarily create a 100 MiB disk named "fake_TailsData"
    And I create a gpt partition labeled "TailsData" with an ext4 filesystem encrypted with password "asdf" on disk "fake_TailsData"
    And I plug sata drive "fake_TailsData"
    When I start the computer
    And the computer boots Tails
    Then drive "fake_TailsData" is detected by Tails
    And Tails Greeter has not detected a persistence partition

  Scenario: Tails can boot from live systems stored on hard drives
    Given a computer
    And I temporarily create a 2 GiB disk named "live_hd"
    And I write the Tails ISO image to disk "live_hd"
    And the computer is set to boot from sata drive "live_hd"
    And I set Tails to boot with options "live-media="
    When I start Tails with network unplugged and I login
    Then Tails is running from sata drive "live_hd"

  Scenario: Tails booting from a DVD does not use live systems stored on hard drives
    Given a computer
    And I temporarily create a 2 GiB disk named "live_hd"
    And I write the Tails ISO image to disk "live_hd"
    And I plug sata drive "live_hd"
    And I start Tails from DVD with network unplugged and I login
    Then drive "live_hd" is detected by Tails
    And drive "live_hd" is not mounted

  Scenario: Booting Tails does not automount untrusted ext2 partitions
    Given a computer
    And I temporarily create a 100 MiB disk named "gpt_ext2"
    And I create a gpt partition with an ext2 filesystem on disk "gpt_ext2"
    And I plug sata drive "gpt_ext2"
    And I start Tails from DVD with network unplugged and I login
    Then drive "gpt_ext2" is detected by Tails
    And drive "gpt_ext2" is not mounted

  Scenario: Booting Tails does not automount untrusted fat32 partitions
    Given a computer
    And I temporarily create a 100 MiB disk named "msdos_fat32"
    And I create an msdos partition with a vfat filesystem on disk "msdos_fat32"
    And I plug sata drive "msdos_fat32"
    And I start Tails from DVD with network unplugged and I login
    Then drive "msdos_fat32" is detected by Tails
    And drive "msdos_fat32" is not mounted
