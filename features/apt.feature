@product
Feature: Installing packages through APT
  As a Tails user
  when I set an administration password in Tails Greeter
  I should be able to install packages using APT and Synaptic
  and all Internet traffic should flow only through Tor.

  Scenario: APT sources are configured correctly
    Given I start Tails from DVD with network unplugged and I login
    Then the only hosts in APT sources are "vwakviie2ienjx6t.onion,sgvtcaew4bxjd7ln.onion,jenw7xbd6tf7vfhp.onion,sdscoq7snqtznauu.onion"
    And no proposed-updates APT suite is enabled
