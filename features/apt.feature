@product
Feature: Installing packages through APT
  As a Tails user
  when I set an administration password in Tails Greeter
  I should be able to install packages using APT and Synaptic
  and all Internet traffic should flow only through Tor.

  Background:
    Given I have started Tails from DVD and logged in with an administration password and the network is connected

  Scenario: APT sources are configured correctly
    Then the only hosts in APT sources are "ftp.us.debian.org,security.debian.org,backports.debian.org,deb.tails.boum.org,deb.torproject.org,mozilla.debian.net"

  #10496: apt-get scenarios are fragile
  @check_tor_leaks @fragile
  Scenario: Install packages using apt
    When I update APT using apt
    Then I should be able to install a package using apt

  #10441: Synaptic test is fragile
  @check_tor_leaks @fragile
  Scenario: Install packages using Synaptic
    When I start Synaptic
    And I update APT using Synaptic
    Then I should be able to install a package using Synaptic
