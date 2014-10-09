@product
Feature: TrueCrypt
  As a Tails user
  I *might* want to use TrueCrypt

  Scenario: TrueCrypt starts
    Given a computer
    And I set Tails to boot with options "truecrypt"
    And I start Tails from DVD with network unplugged and I login
    When I start TrueCrypt through the GNOME menu
    And I deal with the removal warning prompt
    Then I see "TrueCryptWindow.png" after at most 60 seconds
