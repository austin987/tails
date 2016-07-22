@product
Feature: Logging in via SSH
  As a Tails user
  When I connect to SSH servers on the Internet
  all Internet traffic should flow only through Tor

  Background:
    Given I have started Tails from DVD and logged in and the network is connected

  @check_tor_leaks
  Scenario: Connecting to an SSH server on the Internet
    Given I have the SSH key pair for an SSH server
    When I connect to an SSH server on the Internet
    Then I have sucessfully logged into the SSH server

  @check_tor_leaks
  Scenario: Connecting to an SSH server on the LAN
    Given I have the SSH key pair for an SSH server
    And an SSH server is running on the LAN
    When I connect to an SSH server on the LAN
    Then I am prompted to verify the SSH fingerprint for the SSH server

  @check_tor_leaks
  Scenario: Connecting to an SFTP server on the Internet using the GNOME "Connect to Server" feature
    Given I have the SSH key pair for an SFTP server
    When I connect to an SFTP server on the Internet
    Then I successfully connect to the SFTP server
