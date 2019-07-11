@product
Feature: Tails has a sane default configuration

  Scenario: The live user is setup correctly
    Given I have started Tails from DVD without network and logged in
    Then the live user has been setup by live-boot
    And the live user is a member of only its own group and "cdrom dialout floppy video plugdev netdev scanner lp lpadmin vboxsf"
    And the live user owns its home dir and it has normal permissions

  Scenario: No unexpected network services
    Given I have started Tails from DVD without network and logged in
    When the network is plugged
    And Tor is ready
    Then no unexpected services are listening for network connections

