@product
Feature: WhisperBack
  As a Tails user
  I want to be able to report errors to Tails

  Scenario: WhisperBack unit tests
    Given a computer
    And I start Tails from DVD with network unplugged and I login
    Then the WhisperBack unit tests pass
