@product
Feature: Chatting anonymously using Pidgin
  As a Tails user
  when I chat using Pidgin
  all Internet traffic should flow only through Tor

  Background:
    Given a computer
    And I capture all network traffic
    And I start Tails from DVD and I login
    And I save the state so the background can be restored next scenario

  Scenario: Connecting to the #tails IRC channel with the pre-configured account
    Given Pidgin has the expected accounts configured with random nicknames
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    When I activate the "irc.oftc.net" Pidgin account
    Then Pidgin successfully connects to the "irc.oftc.net" account
    And I can join the "#tails" channel on "irc.oftc.net"
    # XXX: OTR
    And all Internet traffic has only flowed through Tor
