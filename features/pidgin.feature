@product
Feature: Chatting anonymously using Pidgin
  As a Tails user
  when I chat using Pidgin
  I should be able to use OTR
  And I should be able to persist my Pidgin configuration
  And AppArmor should prevent Pidgin from doing dangerous things
  And all Internet traffic should flow only through Tor

  Scenario: Make sure Pidgin's D-Bus interface is blocked
    Given I have started Tails from DVD without network and logged in
    When I start "Pidgin Internet Messenger" via GNOME Activities Overview
    Then I see Pidgin's account manager window
    And Pidgin's D-Bus interface is not available

  @check_tor_leaks
  Scenario: Chatting with some friend over XMPP
    Given I have started Tails from DVD and logged in and the network is connected
    When I start "Pidgin Internet Messenger" via GNOME Activities Overview
    Then I see Pidgin's account manager window
    When I create my XMPP account
    And I close Pidgin's account manager window
    Then Pidgin automatically enables my XMPP account
    Given my XMPP friend goes online
    When I start a conversation with my friend
    And I say something to my friend
    Then I receive a response from my friend

  @check_tor_leaks
  Scenario: Chatting with some friend over XMPP in a multi-user chat
    Given I have started Tails from DVD and logged in and the network is connected
    When I start "Pidgin Internet Messenger" via GNOME Activities Overview
    Then I see Pidgin's account manager window
    When I create my XMPP account
    And I close Pidgin's account manager window
    Then Pidgin automatically enables my XMPP account
    When I join some empty multi-user chat
    And I clear the multi-user chat's scrollback
    And my XMPP friend goes online and joins the multi-user chat
    Then I can see that my friend joined the multi-user chat
    And I say something to my friend in the multi-user chat
    Then I receive a response from my friend in the multi-user chat
    When I say https://labs.riseup.net/code/projects/tails/roadmap to my friend in the multi-user chat
    Then I see the Tails roadmap URL
    When I wait 10 seconds
    And I click on the Tails roadmap URL
    Then the Tor Browser loads the Tails roadmap

  @check_tor_leaks
  Scenario: Chatting with some friend over XMPP and with OTR
    Given I have started Tails from DVD and logged in and the network is connected
    When I start "Pidgin Internet Messenger" via GNOME Activities Overview
    Then I see Pidgin's account manager window
    When I create my XMPP account
    And I close Pidgin's account manager window
    Then Pidgin automatically enables my XMPP account
    Given my XMPP friend goes online
    When I start a conversation with my friend
    And I start an OTR session with my friend
    Then Pidgin automatically generates an OTR key
    And an OTR session was successfully started with my friend
    When I say something to my friend
    Then I receive a response from my friend

  @check_tor_leaks
  Scenario: Connecting to the tails multi-user chat with my XMPP account
    Given I have started Tails from DVD and logged in and the network is connected
    When I start "Pidgin Internet Messenger" via GNOME Activities Overview
    Then I see Pidgin's account manager window
    And I create my XMPP account
    And I close Pidgin's account manager window
    Then Pidgin automatically enables my XMPP account
    And I can join the "tails" channel on "conference.riseup.net"

  Scenario: Adding a certificate to Pidgin
    Given I have started Tails from DVD and logged in and the network is connected
    And I start "Pidgin Internet Messenger" via GNOME Activities Overview
    And I see Pidgin's account manager window
    And I close Pidgin's account manager window
    Then I can add a certificate from the "/home/amnesia" directory to Pidgin

  Scenario: Failing to add a certificate to Pidgin
    Given I have started Tails from DVD and logged in and the network is connected
    When I start "Pidgin Internet Messenger" via GNOME Activities Overview
    And I see Pidgin's account manager window
    And I close Pidgin's account manager window
    Then I cannot add a certificate from the "/home/amnesia/.gnupg" directory to Pidgin
    When I close Pidgin's certificate import failure dialog
    And I close Pidgin's certificate manager
    Then I cannot add a certificate from the "/lib/live/mount/overlay/home/amnesia/.gnupg" directory to Pidgin
    When I close Pidgin's certificate import failure dialog
    And I close Pidgin's certificate manager
    Then I cannot add a certificate from the "/live/overlay/home/amnesia/.gnupg" directory to Pidgin

  @check_tor_leaks
  Scenario: Using a persistent Pidgin configuration
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    And the network is plugged
    And Tor is ready
    And available upgrades have been checked
    And all notifications have disappeared
    When I start "Pidgin Internet Messenger" via GNOME Activities Overview
    Then I see Pidgin's account manager window
    When I create my XMPP account
    And I close Pidgin's account manager window
    Then Pidgin automatically enables my XMPP account
    When I close Pidgin
    # And I generate an OTR key for the default Pidgin account
    And I take note of the configured Pidgin accounts
    # And I take note of the OTR key for Pidgin's "conference.riseup.net" account
    And I shutdown Tails and wait for the computer to power off
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled
    And Pidgin has the expected persistent accounts configured
    # And Pidgin has the expected persistent OTR keys
    When I start "Pidgin Internet Messenger" via GNOME Activities Overview
    Then Pidgin automatically enables my XMPP account
    And I join some empty multi-user chat
    # Exercise Pidgin AppArmor profile with persistence enabled.
    # This should really be in dedicated scenarios, but it would be
    # too costly to set up the virtual USB drive with persistence more
    # than once in this feature.
    Given I start monitoring the AppArmor log of "/usr/bin/pidgin"
    Then I cannot add a certificate from the "/home/amnesia/.gnupg" directory to Pidgin
    And AppArmor has denied "/usr/bin/pidgin" from opening "/home/amnesia/.gnupg/test.crt"
    When I close Pidgin's certificate import failure dialog
    And I close Pidgin's certificate manager
    Given I restart monitoring the AppArmor log of "/usr/bin/pidgin"
    Then I cannot add a certificate from the "/live/persistence/TailsData_unlocked/gnupg" directory to Pidgin
    And AppArmor has denied "/usr/bin/pidgin" from opening "/live/persistence/TailsData_unlocked/gnupg/test.crt"
    When I close Pidgin's certificate import failure dialog
    And I close Pidgin's certificate manager
    Then I can add a certificate from the "/home/amnesia" directory to Pidgin
