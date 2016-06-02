@product @doc
Feature: Tails documentation

  Scenario: The "Report an Error" launcher will open the support documentation
    Given I have started Tails from DVD without network and logged in
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    When I double-click the Report an Error launcher on the desktop
    Then the support documentation page opens in Tor Browser
