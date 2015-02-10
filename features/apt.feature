@product
Feature: Installing packages through APT
  As a Tails user
  when I set an administration password in Tails Greeter
  I should be able to install packages using APT and Synaptic
  and all Internet traffic should flow only through Tor.

  Background:
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And I enable more Tails Greeter options
    And I set sudo password "asdf"
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And I save the state so the background can be restored next scenario

  Scenario: APT sources are configured correctly
    Then the only hosts in APT sources are "ftp.us.debian.org,security.debian.org,backports.debian.org,deb.tails.boum.org,deb.torproject.org,mozilla.debian.net"

  Scenario: Install packages using apt-get
    When I update APT using apt-get
    Then I should be able to install a package using apt-get
    And all Internet traffic has only flowed through Tor

  Scenario: Install packages using Synaptic
    When I start Synaptic
    And I update APT using Synaptic
    Then I should be able to install a package using Synaptic
    And all Internet traffic has only flowed through Tor
