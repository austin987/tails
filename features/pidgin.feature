@product
Feature: Chatting anonymously using Pidgin
  As a Tails user
  when I chat using Pidgin
  I should be able to use OTR
  And I should be able to persist my Pidgin configuration
  And AppArmor should prevent Pidgin from doing dangerous things
  And all Internet traffic should flow only through Tor

  Background:
    Given a computer
    When I start Tails from DVD and I login
    Then Pidgin has the expected accounts configured with random nicknames
    And I save the state so the background can be restored next scenario

  @check_tor_leaks
  Scenario: Connecting to the #tails IRC channel with the pre-configured account
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    When I activate the "irc.oftc.net" Pidgin account
    And I close Pidgin's account manager window
    Then Pidgin successfully connects to the "irc.oftc.net" account
    And I can join the "#tails" channel on "irc.oftc.net"
    When I type "/topic"
    And I press the "ENTER" key
    Then I see the Tails roadmap URL
    When I click on the Tails roadmap URL
    Then the Tor Browser has started and loaded the Tails roadmap
    And all Internet traffic has only flowed through Tor

  Scenario: Adding a certificate to Pidgin
    And I start Pidgin through the GNOME menu
    And I see Pidgin's account manager window
    And I close Pidgin's account manager window
    Then I can add a certificate from the "/home/amnesia" directory to Pidgin

  Scenario: Failing to add a certificate to Pidgin
    And I start Pidgin through the GNOME menu
    And I see Pidgin's account manager window
    And I close Pidgin's account manager window
    Then I cannot add a certificate from the "/home/amnesia/.gnupg" directory to Pidgin

  @keep_volumes @check_tor_leaks
  Scenario: Using a persistent Pidgin configuration
    Given the USB drive "current" contains Tails with persistence configured and password "asdf"
    And a computer
    And I start Tails from USB drive "current" and I login with persistence password "asdf"
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    # And I generate an OTR key for the default Pidgin account
    And I take note of the configured Pidgin accounts
    # And I take note of the OTR key for Pidgin's "irc.oftc.net" account
    And I shutdown Tails and wait for the computer to power off
    Given a computer
    And I start Tails from USB drive "current" and I login with persistence password "asdf"
    And Pidgin has the expected persistent accounts configured
    # And Pidgin has the expected persistent OTR keys
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    When I activate the "irc.oftc.net" Pidgin account
    And I close Pidgin's account manager window
    Then Pidgin successfully connects to the "irc.oftc.net" account
    And I can join the "#tails" channel on "irc.oftc.net"
    # Exercise Pidgin AppArmor profile with persistence enabled.
    # This should really be in dedicated scenarios, but it would be
    # too costly to set up the virtual USB drive with persistence more
    # than once in this feature.
    And I cannot add a certificate from the "/home/amnesia/.gnupg" directory to Pidgin
    When I close Pidgin's certificate import failure dialog
    And I close Pidgin's certificate manager
    Then I cannot add a certificate from the "/live/persistence/TailsData_unlocked/gnupg" directory to Pidgin
    When I close Pidgin's certificate import failure dialog
    And I close Pidgin's certificate manager
    Then I can add a certificate from the "/home/amnesia" directory to Pidgin
