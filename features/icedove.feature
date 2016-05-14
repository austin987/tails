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

  Scenario: Icedove defaults to using IMAP
    Then IMAP is the default protocol

  Scenario: Adblock is not enabled within Icedove
    Given I cancel setting up an email account
    When I open Icedove's Add-ons Manager
    And I click the extensions tab
    Then I see that Adblock is not installed in Icedove

  Scenario: Enigmail is configured to use the correct keyserver
    Given I cancel setting up an email account
    And I go into Enigmail's preferences
    When I click Enigmail's keyserver tab
    Then I see that Enigmail is configured to use the correct keyserver
    When I click Enigmail's advanced tab
    Then I see that Enigmail is configured to use the correct SOCKS proxy

  Scenario: Torbirdy is configured to use Tor
    Given I cancel setting up an email account
    And I open Torbirdy's preferences
    Then I see that Torbirdy is configured to use Tor
