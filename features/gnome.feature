@product
Feature: GNOME is well-integrated into Tails

  #13458
  @fragile
  Scenario: A screenshot is taken when the PRINTSCREEN key is pressed
    Given I have started Tails from DVD without network and logged in
    And I wait 10 seconds
    And there is no screenshot in the live user's Pictures directory
    When I press the "PRINTSCREEN" key
    Then a screenshot is saved to the live user's Pictures directory

  Scenario: GNOME notifications are shown to the user
    Given I have started Tails from DVD without network and logged in
    When the "Dogtail rules!" notification is sent
    Then the "Dogtail rules!" notification is shown to the user
