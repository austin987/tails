@product
Feature: Installing packages through APT
  As a Tails user
  when I set an administration password in Tails Greeter
  I should be able to install packages using apt-get and synaptic
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
    And I have a network connection
    And Tor has built a circuit
    And Iceweasel has autostarted and is not loading a web page
    And the time has synced
    And I have closed all annoying notifications
    And APT's sources are only {ftp.us,security,backports}.debian.org
    And I save the state so the background can be restored next scenario

  Scenario: Install packages using apt-get
    When I update APT using apt-get
    Then I should be able to install a package using apt-get
    And all Internet traffic has only flowed through Tor

  Scenario: Install packages using synaptic
    When I run "gksu synaptic"
    And I enter the sudo password in the PolicyKit prompt
    And I update APT using synaptic
    Then I should be able to install a package using synaptic
    And all Internet traffic has only flowed through Tor
