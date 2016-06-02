@product
Feature: Various checks

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
