@product @doc
Feature: Tails documentation

  #15514
  @fragile
  Scenario: The Tails documentation launcher on the desktop works when offline
    Given I have started Tails from DVD without network and logged in
    When I double-click on the Tails documentation launcher on the desktop
    Then "Tails - Documentation" has loaded in the Tor Browser

  #15514
  @fragile
  Scenario: The Tails documentation launcher on the desktop works when online
    Given I have started Tails from DVD and logged in and the network is connected
    When I double-click on the Tails documentation launcher on the desktop
    Then "Tails - Documentation" has loaded in the Tor Browser

  #15321
  @fragile
  Scenario: The Report an Error launcher will open the support documentation
    Given I have started Tails from DVD without network and logged in
    When I double-click on the Report an Error launcher on the desktop
    Then the support documentation page opens in Tor Browser
