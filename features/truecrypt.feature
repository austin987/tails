@product
Feature: TrueCrypt
  As a Tails user
  I *might* want to use TrueCrypt

  Scenario: TrueCrypt starts
    Given a computer
    And I set Tails to boot with options "truecrypt"
    And the network is unplugged
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And I have closed all annoying notifications
    When I start TrueCrypt through the GNOME menu
    Then I see "TrueCryptWindow.png" after at most 60 seconds
