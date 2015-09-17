@product
Feature: Spoofing MAC addresses

  Background:
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And no network devices are present
    And I save the state so the background can be restored next scenario
    And the real MAC address was not leaked

  Scenario: MAC address spoofing is disabled
    When I enable more Tails Greeter options
    And disable MAC spoofing in Tails Greeter
    And I log in to a new session
    And the Tails desktop is ready
    And Tor is ready
    Then 1 network device is present
    And the network device has its default MAC address configured
    And the real MAC address was leaked

  Scenario: MAC address spoofing is successful
    When I log in to a new session
    And the Tails desktop is ready
    And Tor is ready
    Then 1 network device is present
    And the network device has a spoofed MAC address configured
    And the real MAC address was not leaked

  Scenario: MAC address spoofing fails and macchanger returns false
    Given macchanger will fail by not spoofing and always returns false
    When I log in to a new session
    And see the "Network card disabled" notification
    And the Tails desktop is ready
    Then no network devices are present
    And the real MAC address was not leaked

  Scenario: MAC address spoofing fails and macchanger returns true
    Given macchanger will fail by not spoofing and always returns true
    When I log in to a new session
    And see the "Network card disabled" notification
    And the Tails desktop is ready
    Then no network devices are present
    And the real MAC address was not leaked

  Scenario: MAC address spoofing fails and the module is not removed
    Given MAC spoofing will fail, and the module cannot be unloaded
    When I log in to a new session
    And see the "All networking disabled" notification
    And the Tails desktop is ready
    Then 1 network device is present
    But the MAC spoofing panic mode disabled networking
    And the real MAC address was not leaked

  Scenario: MAC address spoofing causes a simulated network failure
    Given the network is unplugged
    When I log in to a new session
    Then the Tails desktop is ready
    When I simulate that a wireless NIC's MAC address is blocked by the network
    Then I see the "Network connection blocked?" notification
