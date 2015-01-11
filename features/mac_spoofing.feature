@product
Feature: Spoofing MAC addresses

  Background:
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And I save the state so the background can be restored next scenario
    And the real MAC address was not leaked

  Scenario: MAC address spoofing is disabled
    When I enable more Tails Greeter options
    And disable MAC spoofing in Tails Greeter
    When I log in to a new session
    And Tor is ready
    Then the network device has its default MAC address configured
    And the real MAC address was leaked

  Scenario: MAC address spoofing is successfull
    When I log in to a new session
    And Tor is ready
    Then the network device has a spoofed MAC address configured
    And the real MAC address was not leaked

  Scenario: MAC address spoofing fails and macchanger returns false
    Given MAC spoofing will fail by not spoofing and always returns false
    When I log in to a new session
    And see the "Network card disabled" notification
    Then the network device was removed
    And the real MAC address was not leaked

  Scenario: MAC address spoofing fails and macchanger returns true
    Given MAC spoofing will fail by not spoofing and always returns true
    When I log in to a new session
    And see the "Network card disabled" notification
    Then the network device was removed
    And the real MAC address was not leaked

#  Scenario: MAC address spoofing fails and the module is not removed
#    Given MAC spoofing will fail, and the module cannot be unloaded
#    When I log in to a new session
#    And see the "All networking disabled" notification
#    And Tor is ready
#    Then the network device was not removed
#    Then networking was disabled
#    And the real MAC address was not leaked
