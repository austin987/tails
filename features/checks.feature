@product
Feature: Various checks

  @doc
  Scenario: The "Report an Error" launcher will open the support documentation
    Given I have started Tails from DVD without network and logged in
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    When I double-click the Report an Error launcher on the desktop
    Then the support documentation page opens in Tor Browser

  Scenario: No initial network
    Given I have started Tails from DVD without network and logged in
    And I wait between 30 and 60 seconds
    Then the Tor Status icon tells me that Tor is not usable
    When the network is plugged
    Then Tor is ready
    And the Tor Status icon tells me that Tor is usable
    And all notifications have disappeared
    And the time has synced

  #11463
  @fragile
  Scenario: The 'Tor is ready' notification is shown when Tor has bootstrapped
    Given I have started Tails from DVD without network and logged in
    And the network is plugged
    When I see the 'Tor is ready' notification
    Then Tor is ready

  Scenario: tails-debugging-info does not leak information
    Given I have started Tails from DVD without network and logged in
    Then tails-debugging-info is not susceptible to symlink attacks

  Scenario: The Tails Greeter "disable all networking" option disables networking within Tails
    Given I have started Tails from DVD without network and stopped at Tails Greeter's login screen
    And I enable more Tails Greeter options
    And I disable all networking in the Tails Greeter
    And I log in to a new session
    Then no network interfaces are enabled
