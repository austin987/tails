@product
Feature: Chatting anonymously using Pidgin
  As a Tails user
  when I chat using Pidgin
  I should be able to use OTR
  And I should be able to persist my Pidgin configuration
  And AppArmor should prevent Pidgin from doing dangerous things
  And all Internet traffic should flow only through Tor

 @check_tor_leaks
 Scenario: Chatting with some friend over XMPP
   Given I reach the "with-network-logged-in" checkpoint
   When I start Pidgin through the GNOME menu
   Then I see Pidgin's account manager window
   When I create my XMPP account
   And I close Pidgin's account manager window
   Then Pidgin automatically enables my XMPP account
   Given my XMPP friend goes online
   When I start a conversation with my friend
   And I say something to my friend
   Then I receive a response from my friend

  @check_tor_leaks
  Scenario: Using a persistent Pidgin configuration
    Given I reach the "usb-install-with-persistence" checkpoint
    And I enable persistence with password "asdf"
    And I log in to a new session
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
