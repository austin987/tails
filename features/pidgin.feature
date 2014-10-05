@product
Feature: Chatting anonymously using Pidgin
  As a Tails user
  when I chat using Pidgin
  I should be able to use OTR
  And I should be able to persist my Pidgin configuration
  And AppArmor should prevent Totem from doing dangerous things
  And all Internet traffic should flow only through Tor

  Background:
    Given a computer
    And I capture all network traffic
    When I start Tails from DVD and I login
    Then Pidgin has the expected accounts configured with random nicknames
    And I save the state so the background can be restored next scenario

  Scenario: Connecting to the #tails IRC channel with the pre-configured account
    When I start Pidgin through the GNOME menu
    Then I see Pidgin's account manager window
    When I activate the "irc.oftc.net" Pidgin account
    And I close Pidgin's account manager window
    Then Pidgin successfully connects to the "irc.oftc.net" account
    And I can join the "#tails" channel on "irc.oftc.net"
    And all Internet traffic has only flowed through Tor
