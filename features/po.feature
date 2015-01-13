@source
Feature: check PO files
  As a Tails developer, when I build Tails, I want to make sure
  the PO files in use are correct.

  Scenario: check all PO files
    Given I am in the Git branch being tested
    Then all the PO files should be correct
