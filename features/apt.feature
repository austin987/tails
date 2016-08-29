@product
Feature: Installing packages through APT
  As a Tails user
  when I set an administration password in Tails Greeter
  I should be able to install packages using APT and Synaptic
  and all Internet traffic should flow only through Tor.

  Scenario: APT sources are configured correctly
    Given I have started Tails from DVD without network and logged in
    Then the only hosts in APT sources are "ftp.us.debian.org,security.debian.org,deb.tails.boum.org,deb.torproject.org"

  @check_tor_leaks
  Scenario: Install packages using apt
    Given I have started Tails from DVD and logged in with an administration password and the network is connected
    And I update APT using apt
    When I install "cowsay" using apt
    Then package "cowsay" is installed

  @check_tor_leaks
  Scenario: Install packages using Synaptic
    Given I have started Tails from DVD and logged in with an administration password and the network is connected
    And I start Synaptic
    And I update APT using Synaptic
    When I install "cowsay" using Synaptic
    Then package "cowsay" is installed
