@product
Feature: Browsing the web using the Unsafe Browser
  As a Tails user
  when I browse the web using the Unsafe Browser
  I should have direct access to the web

  Background:
    Given a computer
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And I save the state so the background can be restored next scenario

  Scenario: Starting the Unsafe Browser works as it should.
    When I successfully start the Unsafe Browser
    Then the Unsafe Browser has a red theme
    And the Unsafe Browser shows a warning as its start page
    And the Unsafe Browser uses all expected TBB shared libraries

  Scenario: Closing the Unsafe Browser shows a stop notification.
    When I successfully start the Unsafe Browser
    And I close the Unsafe Browser
    Then I see the Unsafe Browser stop notification

  Scenario: Starting a second instance of the Unsafe Browser results in an error message being shown.
    When I successfully start the Unsafe Browser
    And I start the Unsafe Browser
    Then I see a warning about another instance already running

  Scenario: Opening check.torproject.org in the Unsafe Browser shows the red onion and a warning message.
    When I successfully start the Unsafe Browser
    And I open the address "https://check.torproject.org" in the Unsafe Browser
    Then I see "UnsafeBrowserTorCheckFail.png" after at most 60 seconds

  Scenario: The Unsafe Browser cannot be configured to use Tor and other local proxies.
    When I successfully start the Unsafe Browser
    Then I cannot configure the Unsafe Browser to use any local proxies
