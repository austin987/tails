#11465
@product @check_tor_leaks
Feature: Thunderbird email client
  As a Tails user
  I may want to use an email client

  Background:
    Given I have started Tails from DVD and logged in and the network is connected
    And I have not configured an email account
    When I start Thunderbird
    Then I am prompted to setup an email account

  Scenario: Only the expected addons are installed
    Given I cancel setting up an email account
    When I open Thunderbird's Add-ons Manager
    And I click the extensions tab
    Then I see that only the Enigmail and TorBirdy addons are enabled in Thunderbird

  Scenario: Torbirdy is configured to use Tor
    Given I cancel setting up an email account
    Then I see that Torbirdy is configured to use Tor

  Scenario: Thunderbird's autoconfiguration wizard defaults to IMAP and secure protocols
    When I enter my email credentials into the autoconfiguration wizard
    Then the autoconfiguration wizard's choice for the incoming server is secure IMAP
    Then the autoconfiguration wizard's choice for the outgoing server is secure SMTP

  Scenario: Thunderbird can send emails, and receive emails over IMAP
    When I enter my email credentials into the autoconfiguration wizard
    Then the autoconfiguration wizard's choice for the incoming server is secure IMAP
    When I accept the autoconfiguration wizard's configuration
    And I send an email to myself
    And I fetch my email
    Then I can find the email I sent to myself in my inbox

  Scenario: Thunderbird can download the inbox with POP3
    When I enter my email credentials into the autoconfiguration wizard
    Then the autoconfiguration wizard's choice for the incoming server is secure IMAP
    When I select the autoconfiguration wizard's POP3 choice
    Then the autoconfiguration wizard's choice for the incoming server is secure POP3
    When I accept the autoconfiguration wizard's configuration
    And I fetch my email
    Then my Thunderbird inbox is non-empty
