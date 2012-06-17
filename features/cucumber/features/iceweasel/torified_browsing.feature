Feature: Iceweasel must be torified.
  In order to be anonymous, the iceweasel web browser must connect through Tor.

  Background:
    Given a freshly started Tails

  Scenario: See check.torproject green page on session startup
    When I log in a new session
    Then I should see YourbrowserT.png
