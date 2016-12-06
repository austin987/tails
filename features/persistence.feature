@product
Feature: Tails persistence
  As a Tails user
  I want to use Tails persistence feature

  Scenario: Booting Tails from a USB drive with a disabled persistent partition
    Given I have started Tails without network from a USB drive with a persistent partition and stopped at Tails Greeter's login screen
    When I log in to a new session
    Then Tails is running from USB drive "__internal"
    And persistence is disabled
    But a Tails persistence partition exists on USB drive "__internal"

  Scenario: Booting Tails from a USB drive with an enabled persistent partition and reconfiguring it
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    Then Tails is running from USB drive "__internal"
    And all persistence presets are enabled
    And all persistent directories have safe access rights
    When I disable the first persistence preset
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with read-only persistence enabled
    Then all persistence presets but the first one are enabled

  Scenario: Writing files first to a read/write-enabled persistent partition, and then to a read-only-enabled persistent partition
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    And the network is plugged
    And Tor is ready
    And I take note of which persistence presets are available
    When I write some files expected to persist
    And I shutdown Tails and wait for the computer to power off
    # XXX: The next step succeeds (and the --debug output confirms that it's actually looking for the files) but will fail in a subsequent scenario restoring the same snapshot. This exactly what we want, but why does it work? What is guestfs's behaviour when qcow2 internal snapshots are involved?
    Then only the expected files are present on the persistence partition on USB drive "__internal"
    Given I start Tails from USB drive "__internal" with network unplugged and I login with read-only persistence enabled
    And I capture all network traffic
    And the network is plugged
    And Tor is ready
    Then Tails is running from USB drive "__internal"
    And the boot device has safe access rights
    And all persistence presets are enabled
    And there is no GNOME bookmark for the persistent Tor Browser directory
    And I write some files not expected to persist
    And I remove some files expected to persist
    And I take note of which persistence presets are available
    And I shutdown Tails and wait for the computer to power off
    Then only the expected files are present on the persistence partition on USB drive "__internal"

  Scenario: Creating and using a persistent NetworkManager connection
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    And the network is plugged
    And Tor is ready
    And I add a current wired DHCP NetworkManager connection called "persistent-con-current"
    And I shutdown Tails and wait for the computer to power off
    Given I start Tails from USB drive "__internal" with network unplugged and I login with read-only persistence enabled
    And I capture all network traffic
    And the network is plugged
    And Tor is ready
    And I switch to the "persistent-con-current" NetworkManager connection
    And the network device has a spoofed MAC address configured
    And the real MAC address was not leaked

  Scenario: Creating and using a Jessie-area persistent NetworkManager connection
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    And the network is plugged
    And Tor is ready
    And I add a 2.x wired DHCP NetworkManager connection called "persistent-con-2.x"
    And I shutdown Tails and wait for the computer to power off
    Given I start Tails from USB drive "__internal" with network unplugged and I login with read-only persistence enabled
    And I capture all network traffic
    And the network is plugged
    And Tor is ready
    And I switch to the "persistent-con-2.x" NetworkManager connection
    And the network device has a spoofed MAC address configured
    And the real MAC address was not leaked

  Scenario: Deleting a Tails persistent partition
    Given I have started Tails without network from a USB drive with a persistent partition and stopped at Tails Greeter's login screen
    And I log in to a new session
    Then Tails is running from USB drive "__internal"
    And the boot device has safe access rights
    And persistence is disabled
    But a Tails persistence partition exists on USB drive "__internal"
    And all notifications have disappeared
    When I delete the persistent partition
    Then there is no persistence partition on USB drive "__internal"

  Scenario: Dotfiles persistence
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    When I write some dotfile expected to persist
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the expected persistent dotfile is present in the filesystem
