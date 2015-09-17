@product
Feature: Microsoft Windows Camouflage
  As a Tails user
  when I select the Microsoft Windows Camouflage in Tails Greeter
  I should be presented with a Microsoft Windows like environment

  Background:
    Given Tails has booted from DVD without network and logged in with windows camouflage enabled

  Scenario: I should be presented with a Microsoft Windows like desktop
    Then I see "WindowsDesktop.png" after at most 10 seconds
    And I see "WindowsStartButton.png" after at most 10 seconds
    And I see "WindowsSysTrayGpgApplet.png" after at most 10 seconds
    And I see "WindowsSysTrayKeyboard.png" after at most 10 seconds
    And I see "WindowsSysTraySound.png" after at most 10 seconds

  Scenario: Windows should appear like those in Microsoft Windows
    When I start the Tor Browser in offline mode
    And the Tor Browser has started in offline mode
    Then I see "WindowsTorBrowserWindow.png" after at most 120 seconds
    And I see "WindowsTorBrowserTaskBar.png" after at most 10 seconds
    And I see "WindowsWindowButtons.png" after at most 10 seconds

  Scenario: The panel menu should look like Microsoft Windows's start menu
    When I click the start menu
    Then I see "WindowsStartMenu.png" after at most 10 seconds
