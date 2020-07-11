@source
Feature: Python doctests
  As a Tails developer, when I build Tails, I want to make sure
  the Python doctests pass.

  Scenario: tails-gdm-error-message Python doctests
    Given I am in the Git branch being tested
    Then the Python doctests for the /usr/local/lib/tails-gdm-error-message script pass
