@product
Feature: Logging in via SSH
  As a Tails user
  When I connect to SSH servers on the Internet
  all Internet traffic should flow only through Tor

  Background:
    Given a computer
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And available upgrades have been checked
    And all notifications have disappeared
    And I save the state so the background can be restored next scenario

  @check_tor_leaks
  Scenario: Connecting to an SSH server on the Internet
    Given I have the SSH key pair for an SSH server
    When I connect to an SSH server on the Internet
    And I verify the SSH fingerprint for the SSH server
    Then I have sucessfully logged into the SSH server

  @check_tor_leaks
  Scenario: Connecting to an SFTP server on the Internet using the GNOME "Connect to a Server" feature
    Given I have the SSH key pair for an SSH server
    When I connect to an SFTP server on the Internet
    And I verify the SSH fingerprint for the SFTP server
    Then I successfully connect to the SFTP server
