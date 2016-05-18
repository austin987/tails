@product
Feature: Localization
  As a Tails user
  I want Tails to be localized in my native language
  And various Tails features should still work

  @doc
  Scenario: The Report an Error launcher will open the support documentation in supported non-English locales
    Given I have started Tails from DVD without network and stopped at Tails Greeter's login screen
    And the network is plugged
    And I log in to a new session in German
    And Tails seems to have booted normally
    And Tor is ready
    When I double-click the Report an Error launcher on the desktop
    Then the support documentation page opens in Tor Browser

  Scenario: The Unsafe Browser can be used in all languages supported in Tails
    Given I have started Tails from DVD and logged in and the network is connected
    Then the Unsafe Browser works in all supported languages
