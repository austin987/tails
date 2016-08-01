@product
Feature: Emergency shutdown

  Scenario: The emergency shutdown applet can shutdown Tails
    Given I have started Tails from DVD without network and logged in
    When I request a shutdown using the emergency shutdown applet
    Then Tails eventually shuts down

  Scenario: The emergency shutdown applet can reboot Tails
    Given I have started Tails from DVD without network and logged in
    When I request a reboot using the emergency shutdown applet
    Then Tails eventually restarts

  Scenario: Tails shuts down on DVD boot medium removal
    Given I have started Tails from DVD without network and logged in
    When I eject the boot medium
    Then Tails eventually shuts down

  #10720
  @fragile
  Scenario: Tails shuts down on USB boot medium removal
    Given I have started Tails without network from a USB drive without a persistent partition and logged in
    When I eject the boot medium
    Then Tails eventually shuts down
