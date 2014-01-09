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
    And I have a network connection
    And Tor has built a circuit
    And Iceweasel has autostarted and is not loading a web page
    And the time has synced
    And I have closed all annoying notifications
    And I save the state so the background can be restored next scenario

  Scenario: Starting the Unsafe Browser works as it should.
    When I start the Unsafe Browser
    Then the Unsafe Browser has started
    And the Unsafe Browser has a red theme
    And the Unsafe Browser has Wikipedia pre-selected in the search bar
    And the Unsafe Browser shows a warning as its start page

  Scenario: Closing the Unsafe Browser shows a stop notification.
    When I start the Unsafe Browser
    Then the Unsafe Browser has started
    And I close the Unsafe Browser
    Then I see the Unsafe Browser stop notification

  Scenario: Starting a second instance of the Unsafe Browser results in an error message being shown.
    When I start the Unsafe Browser
    Then the Unsafe Browser has started
    And I run "sudo unsafe-browser"
    Then I see a warning about another instance already running

  Scenario: The Unsafe Browser cannot be restarted before the previous instance has been cleaned up.
    When I start the Unsafe Browser
    Then the Unsafe Browser has started
    And I close the Unsafe Browser
    And I run "sudo unsafe-browser"
    Then I see a warning about another instance already running

  Scenario: Opening check.torproject.org in the Unsafe Browser shows the red onion and a warning message.
    When I start the Unsafe Browser
    Then the Unsafe Browser has started
    And I open the address "https://check.torproject.org" in the Unsafe Browser
    Then I see "UnsafeBrowserTorCheckFail.png" after at most 60 seconds

  Scenario: The Unsafe Browser cannot be configured to use Tor and other local proxies.
    When I start the Unsafe Browser
    Then the Unsafe Browser has started
    Then I cannot configure the Unsafe Browser to use any local proxies
