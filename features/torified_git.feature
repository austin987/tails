@product
Feature: Cloning a git repository
  As a Tails user
  when I clone a git repository
  all Internet traffic should flow only through Tor

  Background:
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And available upgrades have been checked
    And all notifications have disappeared
    And I save the state so the background can be restored next scenario

  Scenario: Cloning a git repository over HTTPS
    When I run "git clone https://git-tails.immerda.ch/myprivatekeyispublic/testing" in GNOME Terminal
    And process "git" has stopped running after at most 180 seconds
    Then the git repository "testing" has been cloned successfully
