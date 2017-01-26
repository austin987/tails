@product
Feature: Installing packages through APT
  As a Tails user
  when I set an administration password in Tails Greeter
  I should be able to install packages using APT and Synaptic
  and all Internet traffic should flow only through Tor.

  Scenario: APT sources are configured correctly
    Given I have started Tails from DVD without network and logged in
    Then the only hosts in APT sources are "vwakviie2ienjx6t.onion,sgvtcaew4bxjd7ln.onion,jenw7xbd6tf7vfhp.onion,sdscoq7snqtznauu.onion"

  @check_tor_leaks
  Scenario: Install packages using apt
    Given I have started Tails from DVD and logged in with an administration password and the network is connected
    When I configure APT to use non-onion sources
    And I update APT using apt
    Then I should be able to install a package using apt

  @check_tor_leaks
  Scenario: Install packages using Synaptic
    Given I have started Tails from DVD and logged in with an administration password and the network is connected
    When I configure APT to use non-onion sources
    And I start Synaptic
    And I update APT using Synaptic
    When I install "cowsay" using Synaptic
    Then the package "cowsay" is installed
