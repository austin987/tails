@product
Feature: Installing packages through APT
  As a Tails user
  when I set an administration password in Tails Greeter
  I should be able to install packages using APT and Synaptic
  and all Internet traffic should flow only through Tor.

  Scenario: APT sources are configured correctly
    Given a computer
    And the computer is set to boot from the Tails DVD
    And the network is unplugged
    And I start the computer
    And the computer boots Tails with genuine APT sources
    And I log in to a new session
    And all notifications have disappeared
    Then the only hosts in APT sources are "vwakviie2ienjx6t.onion,sgvtcaew4bxjd7ln.onion,jenw7xbd6tf7vfhp.onion,sdscoq7snqtznauu.onion"
    And no proposed-updates APT suite is enabled
