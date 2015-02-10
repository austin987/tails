@product
Feature: Getting a DHCP lease without leaking too much information
  As a Tails user
  when I connect to a network with a DHCP server
  I should be able to connect to the Internet
  and the hostname should not have been leaked on the network.

  Scenario: Getting a DHCP lease with the default NetworkManager connection
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    Then the hostname should not have been leaked on the network

  Scenario: Getting a DHCP lease with a manually configured NetworkManager connection
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And I add a wired DHCP NetworkManager connection called "manually-added-con"
    And I switch to the "manually-added-con" NetworkManager connection
    Then the hostname should not have been leaked on the network
