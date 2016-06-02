@product
Feature: Tails-related cryptographic keys are up-to-date

  Scenario: The shipped Tails OpenPGP keys are up-to-date
    Given I have started Tails from DVD without network and logged in
    Then the OpenPGP keys shipped with Tails will be valid for the next 3 months

  Scenario: The Tails Debian repository key is up-to-date
    Given I have started Tails from DVD without network and logged in
    Then the shipped Debian repository key will be valid for the next 3 months
