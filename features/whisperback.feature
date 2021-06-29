@product
Feature: WhisperBack
  As a Tails user
  I want to be able to report errors to Tails

  Scenario: WhisperBack unit tests
    Given I have started Tails from DVD without network and logged in
    Then the WhisperBack unit tests pass
