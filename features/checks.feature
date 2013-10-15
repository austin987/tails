@product
Feature: Various checks

  Background:
    Given a computer
    And the network is unplugged
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And I save the state so the background can be restored next scenario

  Scenario: VirtualBox guest modules are available
    When Tails has booted a 686-pae kernel
    Then the VirtualBox guest modules are available

   Scenario: The shipped Tails signing key is up-to-date
    Given the network is plugged
    And Tor has built a circuit
    Then the shipped Tails signing key is not outdated

  Scenario: The live user is setup correctly
    Then the live user has been setup by live-boot
    And the live user is a member of only its own group and "audio cdrom dialout floppy video plugdev netdev fuse scanner lp lpadmin vboxsf"
    And the live user owns its home dir and it has normal permissions

  Scenario: No initial network
    Given I wait between 30 and 60 seconds
    When the network is plugged
    Then I have a network connection
    And Tor has built a circuit
    And process "vidalia" is running
    And the time has synced

  Scenario: No unexpected network services
    When the network is plugged
    And I have a network connection
    Then no unexpected services are listening for network connections

  # We ditch the background snapshot for this scenario since we cannot
  # add a filesystem share to a live VM so it would have to be in the
  # background above. However, there's a bug that seems to make shares
  # impossible to have after a snapshot restore.
  Scenario: MAT can clean a PDF file
    Given a computer
    And the network is unplugged
    And I setup a filesystem share containing a sample PDF
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    Then MAT can clean some sample PDF file
