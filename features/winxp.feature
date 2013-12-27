@product
Feature: Microsoft Windows XP Camouflage
  As a Tails user
  when I select the Microsoft Windows XP Camouflage in Tails Greeter
  I should be presented with a Microsoft Windows XP like environment

  Background:
    Given a computer
    And the network is unplugged
    And I start the computer
    And the computer boots Tails
    And I enable more Tails Greeter options
    And I enable Microsoft Windows XP camouflage
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    And I save the state so the background can be restored next scenario

  Scenario: I should be presented with a Microsoft Windows XP like desktop
    Then I see "WinXPDesktop.png" after at most 10 seconds
    And I see "WinXPStartButton.png" after at most 10 seconds
    And I see "WinXPLaunchers.png" after at most 10 seconds
    And I see "WinXPSysTray.png" after at most 10 seconds

  Scenario: Windows should appear like those in Microsoft Windows XP
    When I run "iceweasel"
    Then I see "WinXPIceweaselWindow.png" after at most 120 seconds
    # FIXME: #6536
    And I see "WinXPIceweaselTaskBar.png" after at most 10 seconds
    And I see "WinXPWindowButtons.png" after at most 10 seconds

  Scenario: The panel menu should look like Microsoft Windows XP's start menu
    When I click the start menu
    Then I see "WinXPStartMenu.png" after at most 10 seconds
