@product
Feature: I2P
  As a Tails user
  I *might* want to use I2P

  Scenario: I2P is disabled by default
    Given Tails has booted from DVD and logged in and the network is connected
    Then the I2P Browser desktop file is not present
    And the I2P Browser sudo rules are not present
    And the I2P firewall rules are disabled

  Scenario: I2P is enabled when the "i2p" boot parameter is added
    Given Tails has booted from DVD with I2P enabled and logged in and the network is connected
    Then the I2P Browser desktop file is present
    And the I2P Browser sudo rules are enabled
    And the I2P firewall rules are enabled

  Scenario: The I2P Browser works as it should
    Given Tails has booted from DVD with I2P enabled and logged in and the network is connected
    And the I2P router console is ready
    When I start the I2P Browser through the GNOME menu
    Then the I2P router console is displayed in I2P Browser
    And the I2P Browser uses all expected TBB shared libraries

  Scenario: Closing the I2P Browser shows a stop notification and properly tears down the chroot.
    Given Tails has booted from DVD with I2P enabled and logged in and the network is connected
    And the I2P router console is ready
    When I successfully start the I2P Browser
    And I close the I2P Browser
    Then I see the I2P Browser stop notification
    And the I2P Browser chroot is torn down

  Scenario: The I2P internal websites can be viewed in I2P Browser
    Given Tails has booted from DVD with I2P enabled and logged in and the network is connected
    And the I2P router console is ready
    When I start the I2P Browser through the GNOME menu
    Then the I2P router console is displayed in I2P Browser
    And I2P successfully built a tunnel
    When I open the address "http://i2p-projekt.i2p" in the I2P Browser
    Then the I2P homepage loads in I2P Browser

 Scenario: I2P is configured to run in Hidden mode
    Given Tails has booted from DVD with I2P enabled and logged in and the network is connected
    And the I2P router console is ready
    When I start the I2P Browser through the GNOME menu
    Then the I2P router console is displayed in I2P Browser
    And I2P is running in hidden mode

  Scenario: Connecting to the #i2p IRC channel with the pre-configured account
    Given Tails has booted from DVD with I2P enabled and logged in and the network is connected
    And the I2P router console is ready
    And I2P successfully built a tunnel
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    When I activate the "I2P" Pidgin account
    And I close Pidgin's account manager window
    Then Pidgin successfully connects to the "I2P" account
    And I can join the "#i2p" channel on "I2P"

  Scenario: I2P displays a notice when bootstrapping fails
    Given a computer
    And the network is unplugged
    And I set Tails to boot with options "i2p"
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    Then I2P is not running
    When the network is plugged
    And Tor has built a circuit
    And I2P is running
    And I2P's reseeding started
    And the network is unplugged
    Then I see a notification that I2P is not ready
    And I2P's reseeding failed
    But I2P is still running
    When I start the I2P Browser through the GNOME menu
    Then the I2P router console is displayed in I2P Browser

  Scenario: I2P displays a notice when it fails to start
    Given a computer
    And the network is unplugged
    And I set Tails to boot with options "i2p"
    And I start the computer
    And the computer boots Tails
    And I block the I2P router console port
    And I log in to a new session
    Then I2P is not running
    When the network is plugged
    And Tor has built a circuit
    Then I2P is running
    But the network is unplugged
    Then I see a notification that I2P failed to start
    And I2P is not running
