@product
Feature: Browsing the web using the Tor Browser
  As a Tails user
  when I browse the web using the Tor Browser
  all Internet traffic should flow only through Tor

  Background:
    Given a computer
    And I capture all network traffic
    And I start the computer
    And the computer boots Tails
    And I log in to a new session
    And GNOME has started
    And Tor is ready
    And available upgrades have been checked
    And all notifications have disappeared
    And I save the state so the background can be restored next scenario

  Scenario: The Tor Browser directory is usable
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    Then the amnesiac Tor Browser directory exists
    And there is a GNOME bookmark for the amnesiac Tor Browser directory
    And the persistent Tor Browser directory does not exist
    And I can save the current page as "index.html" to the default downloads directory
    And I can print the current page as "output.pdf" to the default downloads directory

  Scenario: Importing an OpenPGP key from a website
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    And I open the address "https://tails.boum.org/tails-signing.key" in the Tor Browser
    Then I see "OpenWithImportKey.png" after at most 20 seconds
    When I accept to import the key with Seahorse
    Then I see "KeyImportedNotification.png" after at most 10 seconds

  Scenario: Playing HTML5 audio
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    And no application is playing audio
    And I open the address "http://www.terrillthompson.com/tests/html5-audio.html" in the Tor Browser
    And I click the HTML5 play button
    And 1 application is playing audio after 10 seconds
    And all Internet traffic has only flowed through Tor

  Scenario: Watching a WebM video
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    And I open the address "https://webm.html5.org/test.webm" in the Tor Browser
    And I click the blocked video icon
    And I see "TorBrowserNoScriptTemporarilyAllowDialog.png" after at most 10 seconds
    And I accept to temporarily allow playing this video
    Then I see "TorBrowserSampleRemoteWebMVideoFrame.png" after at most 180 seconds
    And all Internet traffic has only flowed through Tor

  Scenario: I can view a file stored in "~/Tor Browser" but not in ~/.gnupg
    Given I copy "/usr/share/synaptic/html/index.html" to "/home/amnesia/Tor Browser/synaptic.html" as user "amnesia"
    And I copy "/usr/share/synaptic/html/index.html" to "/home/amnesia/.gnupg/synaptic.html" as user "amnesia"
    And I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    When I open the address "file:///home/amnesia/Tor Browser/synaptic.html" in the Tor Browser
    Then I see "TorBrowserSynapticManual.png" after at most 10 seconds
    When I open the address "file:///home/amnesia/.gnupg/synaptic.html" in the Tor Browser
    Then I see "TorBrowserUnableToOpen.png" after at most 10 seconds

  Scenario: The "Tails documentation" link on the Desktop works
    When I double-click on the "Tails documentation" link on the Desktop
    Then the Tor Browser has started
    And I see "TailsOfflineDocHomepage.png" after at most 10 seconds

  Scenario: The Tor Browser uses TBB's shared libraries
    When I start the Tor Browser
    And the Tor Browser has started
    Then the Tor Browser uses all expected TBB shared libraries

  Scenario: Opening check.torproject.org in the Tor Browser shows the green onion and the congratulations message
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    And I open the address "https://check.torproject.org" in the Tor Browser
    Then I see "TorBrowserTorCheck.png" after at most 180 seconds
    And all Internet traffic has only flowed through Tor

  Scenario: The Tor Browser should not have any plugins enabled
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    Then the Tor Browser has no plugins installed
