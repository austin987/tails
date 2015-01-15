@product
Feature: I2P
  As a Tails user
  I *might* want to use I2P

  Scenario: I2P is disabled by default
    Given a computer
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And all notifications have disappeared
    Then the I2P Browser desktop file is not present
    And the I2P Browser sudo rules are not present
    And the I2P firewall rules are disabled

  Scenario: I2P is enabled when the "i2p" boot parameter is added
    Given a computer
    And I set Tails to boot with options "i2p"
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And I2P is running
    And the I2P router console is ready
    And all notifications have disappeared
    Then the I2P Browser desktop file is present
    And the I2P Browser sudo rules are enabled
    And the I2P firewall rules are enabled
    When I start the I2P Browser through the GNOME menu
    Then I see "I2P_router_console.png" after at most 120 seconds
    And the I2P Browser uses all expected TBB shared libraries
