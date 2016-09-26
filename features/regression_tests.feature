@product
Feature: Regressions tests

  Scenario: tails-debugging-info does not leak information
    Given I have started Tails from DVD without network and logged in
    Then tails-debugging-info is not susceptible to symlink attacks
