@product
Feature: Shutdown applet

  Scenario: The shutdown applet can shutdown Tails
    Given I have started Tails from DVD and logged in and the network is connected
    When I request a shutdown using the emergency shutdown applet
    Then Tails eventually shuts down

  Scenario: The shutdown applet can reboot Tails
    Given I have started Tails from DVD and logged in and the network is connected
    When I request a reboot using the emergency shutdown applet
    Then Tails eventually restarts
