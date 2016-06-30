@product @check_tor_leaks
Feature: Cloning a Git repository
  As a Tails user
  when I clone a Git repository
  all Internet traffic should flow only through Tor

  Background:
    Given I have started Tails from DVD and logged in and the network is connected

  Scenario: Cloning a Git repository anonymously over HTTPS
    When I give Git 180 seconds to clone "https://git-tails.immerda.ch/myprivatekeyispublic/testing"
    Then the Git repository "testing" has been cloned successfully

  Scenario: Cloning a Git repository anonymously over the Git protocol
    When I give Git 180 seconds to clone "git://git.tails.boum.org/myprivatekeyispublic/testing"
    Then the Git repository "testing" has been cloned successfully

  Scenario: Cloning git repository over SSH
    Given I have the SSH key pair for a Git repository
    When I give Git 180 seconds to clone "tails@git.tails.boum.org:myprivatekeyispublic/testing"
    Then the Git repository "testing" has been cloned successfully
