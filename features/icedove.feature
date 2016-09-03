#11465
@product @check_tor_leaks
Feature: Icedove email client
  As a Tails user
  I may want to use an email client

  Background:
    Given I have started Tails from DVD and logged in and the network is connected
    When I start "Icedove" via the GNOME "Internet" applications menu
    And Icedove has started
    And I have not configured an email account
    Then I am prompted to setup an email account

  Scenario: Only the expected addons are installed
    Given I cancel setting up an email account
    When I open Icedove's Add-ons Manager
    And I click the extensions tab
    Then I see that only the amnesia branding, Enigmail and TorBirdy addons are enabled in Icedove

  Scenario: Enigmail is configured to use the correct keyserver
    Given I cancel setting up an email account
    And I go into Enigmail's preferences
    And I enable Enigmail's expert settings
    When I click Enigmail's Keyserver tab
    Then I see that Enigmail is configured to use the correct keyserver
    When I click Enigmail's Advanced tab
    Then I see that Enigmail is configured to use the correct SOCKS proxy

  Scenario: Torbirdy is configured to use Tor
    Given I cancel setting up an email account
    Then I see that Torbirdy is configured to use Tor

  Scenario: Icedove's autoconfiguration wizard defaults to IMAP and secure protocols
    When I enter my email credentials into the autoconfiguration wizard
    Then the autoconfiguration wizard defaults to secure incoming IMAP
    And the autoconfiguration wizard defaults to secure outgoing SMTP

  Scenario: Icedove can send emails, and receive emails over IMAP
    When I enter my email credentials into the autoconfiguration wizard
    And I accept the autoconfiguration wizard's default (IMAP) choice
    And I send an email to myself
    And I fetch my email
    Then I can find the email I sent to myself in my inbox

  Scenario: Icedove can send emails, and receive emails over POP
    When I enter my email credentials into the autoconfiguration wizard
    And I accept the autoconfiguration wizard's alternative (POP) choice
    And I send an email to myself
    And I fetch my email
    Then I can find the email I sent to myself in my inbox
