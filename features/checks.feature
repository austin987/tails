@product
Feature: Various checks

  Scenario: AppArmor is enabled and has enforced profiles
    Given Tails has booted from DVD without network and logged in
    Then AppArmor is enabled
    And some AppArmor profiles are enforced

  Scenario: GNOME Screenshot has a sane default save directory
    Given Tails has booted from DVD without network and logged in
    Then GNOME Screenshot is configured to save files to the live user's home directory

  Scenario: GNOME Screenshot takes a screenshot when the PRINTSCREEN key is pressed
    Given Tails has booted from DVD without network and logged in
    And there is no screenshot in the live user's home directory
    When I press the "PRINTSCREEN" key
    Then a screenshot is saved to the live user's home directory

  Scenario: VirtualBox guest modules are available
    Given Tails has booted from DVD without network and logged in
    When Tails has booted a 64-bit kernel
    Then the VirtualBox guest modules are available

  Scenario: The shipped Tails signing key is up-to-date
    Given Tails has booted from DVD without network and logged in
    Then the shipped Tails signing key will be valid for the next 3 months

  Scenario: The Tails Debian repository key is up-to-date
    Given Tails has booted from DVD without network and logged in
    Then the shipped Tails Debian repository key will be valid for the next 3 months

  Scenario: The "Report an Error" launcher will open the support documentation
    Given Tails has booted from DVD without network and logged in
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    When I double-click the Report an Error launcher on the desktop
    Then the support documentation page opens in Tor Browser

  Scenario: The live user is setup correctly
    Given Tails has booted from DVD without network and logged in
    Then the live user has been setup by live-boot
    And the live user is a member of only its own group and "audio cdrom dialout floppy video plugdev netdev fuse scanner lp lpadmin vboxsf"
    And the live user owns its home dir and it has normal permissions

  Scenario: No initial network
    Given Tails has booted from DVD without network and logged in
    And I wait between 30 and 60 seconds
    When the network is plugged
    And Tor is ready
    And all notifications have disappeared
    And the time has synced
    And process "vidalia" is running within 30 seconds

  Scenario: The 'Tor is ready' notification is shown when Tor has bootstrapped
    Given Tails has booted from DVD without network and logged in
    And the network is plugged
    When I see the 'Tor is ready' notification
    Then Tor is ready

  Scenario: The tor process should be confined with Seccomp
    Given Tails has booted from DVD without network and logged in
    And the network is plugged
    And Tor is ready
    Then the running process "tor" is confined with Seccomp in filter mode

  Scenario: No unexpected network services
    Given Tails has booted from DVD without network and logged in
    When the network is plugged
    And Tor is ready
    Then no unexpected services are listening for network connections

  Scenario: The emergency shutdown applet can shutdown Tails
    Given Tails has booted from DVD without network and logged in
    When I request a shutdown using the emergency shutdown applet
    Then Tails eventually shuts down

  Scenario: The emergency shutdown applet can reboot Tails
    Given Tails has booted from DVD without network and logged in
    When I request a reboot using the emergency shutdown applet
    Then Tails eventually restarts

  # We cannot restore from a snapshot for this scenario since we cannot
  # add a filesystem share to a live VM so it would have to be in the
  # background above. However, there's a bug that seems to make shares
  # impossible to have after a snapshot restore.
  Scenario: MAT can clean a PDF file
    Given a computer
    And I setup a filesystem share containing a sample PDF
    And I start Tails from DVD with network unplugged and I login
    Then MAT can clean some sample PDF file

  Scenario: The Report an Error launcher will open the support documentation in supported non-English locales
    Given Tails has booted from DVD without network and stopped at Tails Greeter's login screen
    And the network is plugged
    And I log in to a new session in German
    And Tails seems to have booted normally
    And Tor is ready
    When I double-click the Report an Error launcher on the desktop
    Then the support documentation page opens in Tor Browser
