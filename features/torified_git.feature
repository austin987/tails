@product @check_tor_leaks @fragile
Feature: Cloning a Git repository
  As a Tails user
  when I clone a Git repository
  all Internet traffic should flow only through Tor

  Background:
    Given I have started Tails from DVD and logged in and the network is connected

  @fragile
  Scenario: Cloning a Git repository anonymously over HTTPS
    When I run "git clone https://git-tails.immerda.ch/myprivatekeyispublic/testing" in GNOME Terminal
    Then process "git" is running within 10 seconds
    And process "git" has stopped running after at most 180 seconds
    And the Git repository "testing" has been cloned successfully

  Scenario: Cloning a Git repository anonymously over the Git protocol
    When I run "git clone git://git.tails.boum.org/myprivatekeyispublic/testing" in GNOME Terminal
    Then process "git" is running within 10 seconds
    And process "git" has stopped running after at most 180 seconds
    And the Git repository "testing" has been cloned successfully

  Scenario: Cloning git repository over SSH
    Given I have the SSH key pair for a Git repository
    When I run "git clone tails@git.tails.boum.org:myprivatekeyispublic/testing" in GNOME Terminal
    Then process "git" is running within 10 seconds
    When I verify the SSH fingerprint for the Git repository
    And process "git" has stopped running after at most 180 seconds
    Then the Git repository "testing" has been cloned successfully
