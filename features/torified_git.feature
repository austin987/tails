@product
Feature: Cloning a Git repository
  As a Tails user
  when I clone a Git repository
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

  Scenario: Cloning a Git repository anonymously over HTTPS
    When I run "git clone https://git-tails.immerda.ch/myprivatekeyispublic/testing" in GNOME Terminal
    And process "git" has stopped running after at most 180 seconds
    Then the Git repository "testing" has been cloned successfully

  Scenario: Cloning a Git repository anonymously over the Git protocol
    When I run "git clone git://git.tails.boum.org/myprivatekeyispublic/testing" in GNOME Terminal
    And process "git" has stopped running after at most 180 seconds
    Then the Git repository "testing" has been cloned successfully
