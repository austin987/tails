@product @doc
Feature: Tails documentation

  Scenario: The Report an Error launcher will open the support documentation
    Given I have started Tails from DVD without network and logged in
    When I double-click on the Report an Error launcher on the desktop
    Then the support documentation page opens in Tor Browser
