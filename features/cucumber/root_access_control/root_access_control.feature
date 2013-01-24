Feature: Root access control enforcement
  As a Tails user
  when I set an administration password in Tails Greeter
  I can use the password for attaining administrative privileges.
  But when I do not set an administration password
  I should not be able to attain administration privileges at all.

  Background:
    Given I restore the background snapshot if it exists
    And a freshly started Tails
    And I save the background snapshot if it does not exist

  Scenario: If an administrative password is set in Tails Greeter the amnesia user should be able to run arbitrary commands with administrative privileges.
    Given I log in to a new session with sudo password "asdf"
    Then I should be able to run administration commands as amnesia

  Scenario: If no administrative password is set in Tails Greeter the amnesia user should not be able to run arbitrary commands administrative privileges.
    Given I log in to a new session
    Then I should not be able to run administration commands as amnesia

  Scenario: If an administrative password is set in Tails Greeter the amnesia user should be able to get administrative privileges through PolicyKit
    Given I log in to a new session with sudo password "asdf"
    And GNOME has started
    Then I should be able to run synaptic

  Scenario: If no administrative password is set in Tails Greeter the amnesia user should not be able to get administrative privileges through PolicyKit.
    Given I log in to a new session
    And GNOME has started
    Then I should not be able to run synaptic
