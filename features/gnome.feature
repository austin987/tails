@product
Feature: GNOME is well-integrated into Tails

  Scenario: A screenshot is taken when the PRINTSCREEN key is pressed
    Given I have started Tails from DVD without network and logged in
    And there is no screenshot in the live user's Pictures directory
    When I press the "PRINTSCREEN" key
    Then a screenshot is saved to the live user's Pictures directory
