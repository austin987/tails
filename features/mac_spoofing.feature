@product
Feature: Spoofing MAC addresses
  In order to not reveal information about the physical location
  As a Tails user
  I want to be able to control whether my network devices MAC addresses should be spoofed
  And I want this feature to fail safe and notify me in case of errors

  Background:
    Given I have started Tails from DVD without network and stopped at Tails Greeter's login screen
    And I capture all network traffic
    And the network is plugged

  @fragile
  Scenario: MAC address spoofing is disabled
    When I enable more Tails Greeter options
    And I disable MAC spoofing in Tails Greeter
    And I log in to a new session
    And the Tails desktop is ready
    And Tor is ready
    Then 1 network interface is enabled
    And the network device has its default MAC address configured
    And the real MAC address was leaked

  @fragile
  Scenario: MAC address spoofing is successful
    When I log in to a new session
    And the Tails desktop is ready
    And Tor is ready
    Then 1 network interface is enabled
    And the network device has a spoofed MAC address configured
    And the real MAC address was not leaked

  #10774
  @fragile
  Scenario: MAC address spoofing fails and macchanger returns false
    Given macchanger will fail by not spoofing and always returns false
    When I log in to a new session
    And see the "Network card disabled" notification
    And the Tails desktop is ready
    Then no network interfaces are enabled
    And the real MAC address was not leaked

  #10774
  @fragile
  Scenario: MAC address spoofing fails and macchanger returns true
    Given macchanger will fail by not spoofing and always returns true
    When I log in to a new session
    And see the "Network card disabled" notification
    And the Tails desktop is ready
    Then no network interfaces are enabled
    And the real MAC address was not leaked

  #10774
  @fragile
  Scenario: MAC address spoofing fails and the module is not removed
    Given macchanger will fail by not spoofing and always returns true
    And no network interface modules can be unloaded
    When I log in to a new session
    And see the "All networking disabled" notification
    And the Tails desktop is ready
    Then 1 network interface is enabled
    But the MAC spoofing panic mode disabled networking
    And the real MAC address was not leaked

  Scenario: The MAC address is not leaked when booting Tails
    Given a computer
    And I capture all network traffic
    When I start the computer
    Then the computer boots Tails
    And no network interfaces are enabled
    And the real MAC address was not leaked
