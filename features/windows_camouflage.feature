@product
Feature: Microsoft Windows Camouflage
  As a Tails user
  when I select the Microsoft Windows Camouflage in Tails Greeter
  I should be presented with a Microsoft Windows like environment

  Background:
    Given a computer
    And the network is unplugged
    And I start the computer
    And the computer boots Tails
    And I enable more Tails Greeter options
    And I enable Microsoft Windows camouflage
    And I log in to a new session
    And GNOME has started
    And all notifications have disappeared
    And I save the state so the background can be restored next scenario

  Scenario: I should be presented with a Microsoft Windows like desktop
    Then I see "WindowsDesktop.png" after at most 10 seconds
    And I see "WindowsStartButton.png" after at most 10 seconds
    And I see "WindowsSysTrayGpgApplet.png" after at most 10 seconds
    And I see "WindowsSysTrayKeyboard.png" after at most 10 seconds
    And I see "WindowsSysTraySound.png" after at most 10 seconds

  Scenario: Windows should appear like those in Microsoft Windows
    When the network is plugged
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And I start the Tor Browser
    Then I see "WindowsTorBrowserWindow.png" after at most 120 seconds
    And I see "WindowsTorBrowserTaskBar.png" after at most 10 seconds
    And I see "WindowsWindowButtons.png" after at most 10 seconds

  Scenario: The panel menu should look like Microsoft Windows's start menu
    When I click the start menu
    Then I see "WindowsStartMenu.png" after at most 10 seconds
