@product
Feature: Root access control enforcement
  As a Tails user
  when I set an administration password in Tails Greeter
  I can use the password for attaining administrative privileges.
  But when I do not set an administration password
  I should not be able to attain administration privileges at all.

  Scenario: If an administrative password is set in Tails Greeter the live user should be able to run arbitrary commands with administrative privileges.
    Given I have started Tails from DVD without network and logged in with an administration password
    Then I should be able to run administration commands as the live user

  Scenario: If no administrative password is set in Tails Greeter the live user should not be able to run arbitrary commands administrative privileges.
    Given I have started Tails from DVD without network and logged in
    Then I should not be able to run administration commands as the live user with the "" password
    And I should not be able to run administration commands as the live user with the "amnesia" password
    And I should not be able to run administration commands as the live user with the "live" password

  Scenario: If an administrative password is set in Tails Greeter the live user should be able to get administrative privileges through PolicyKit
    Given I have started Tails from DVD without network and logged in with an administration password
    And running a command as root with pkexec requires PolicyKit administrator privileges
    Then I should be able to run a command as root with pkexec

  Scenario: If no administrative password is set in Tails Greeter the live user should not be able to get administrative privileges through PolicyKit with the standard passwords.
    Given I have started Tails from DVD without network and logged in
    And running a command as root with pkexec requires PolicyKit administrator privileges
    Then I should not be able to run a command as root with pkexec and the standard passwords
