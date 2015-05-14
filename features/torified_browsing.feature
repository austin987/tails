@product
Feature: Browsing the web using the Tor Browser
  As a Tails user
  when I browse the web using the Tor Browser
  all Internet traffic should flow only through Tor

  Scenario: The Tor Browser directory is usable
    Given Tails has booted from DVD and logged in and the network is connected
    Then the amnesiac Tor Browser directory exists
    And there is a GNOME bookmark for the amnesiac Tor Browser directory
    And the persistent Tor Browser directory does not exist
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    Then I can save the current page as "index.html" to the default downloads directory
    And I can print the current page as "output.pdf" to the default downloads directory

  @check_tor_leaks
  Scenario: Importing an OpenPGP key from a website
    Given Tails has booted from DVD and logged in and the network is connected
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    And I open the address "https://tails.boum.org/tails-signing.key" in the Tor Browser
    Then I see "OpenWithImportKey.png" after at most 20 seconds
    When I accept to import the key with Seahorse
    Then I see "KeyImportedNotification.png" after at most 10 seconds

  @check_tor_leaks
  Scenario: Playing HTML5 audio
    Given Tails has booted from DVD and logged in and the network is connected
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    And no application is playing audio
    And I open the address "http://www.terrillthompson.com/tests/html5-audio.html" in the Tor Browser
    And I click the HTML5 play button
    And 1 application is playing audio after 10 seconds

  @check_tor_leaks
  Scenario: Watching a WebM video
    Given Tails has booted from DVD and logged in and the network is connected
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    And I open the address "https://webm.html5.org/test.webm" in the Tor Browser
    And I click the blocked video icon
    And I see "TorBrowserNoScriptTemporarilyAllowDialog.png" after at most 10 seconds
    And I accept to temporarily allow playing this video
    Then I see "TorBrowserSampleRemoteWebMVideoFrame.png" after at most 180 seconds

  Scenario: I can view a file stored in "~/Tor Browser" but not in ~/.gnupg
    Given Tails has booted from DVD and logged in and the network is connected
    Given I copy "/usr/share/synaptic/html/index.html" to "/home/amnesia/Tor Browser/synaptic.html" as user "amnesia"
    And I copy "/usr/share/synaptic/html/index.html" to "/home/amnesia/.gnupg/synaptic.html" as user "amnesia"
    And I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    When I open the address "file:///home/amnesia/Tor Browser/synaptic.html" in the Tor Browser
    Then I see "TorBrowserSynapticManual.png" after at most 10 seconds
    When I open the address "file:///home/amnesia/.gnupg/synaptic.html" in the Tor Browser
    Then I see "TorBrowserUnableToOpen.png" after at most 10 seconds

  Scenario: The "Tails documentation" link on the Desktop works
    Given Tails has booted from DVD and logged in and the network is connected
    When I double-click on the "Tails documentation" link on the Desktop
    Then the Tor Browser has started
    And I see "TailsOfflineDocHomepage.png" after at most 10 seconds

  Scenario: The Tor Browser uses TBB's shared libraries
    Given Tails has booted from DVD and logged in and the network is connected
    When I start the Tor Browser
    And the Tor Browser has started
    Then the Tor Browser uses all expected TBB shared libraries

  @check_tor_leaks
  Scenario: Opening check.torproject.org in the Tor Browser shows the green onion and the congratulations message
    Given Tails has booted from DVD and logged in and the network is connected
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    And I open the address "https://check.torproject.org" in the Tor Browser
    Then I see "TorBrowserTorCheck.png" after at most 180 seconds

  Scenario: The Tor Browser should not have any plugins enabled
    Given Tails has booted from DVD and logged in and the network is connected
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    Then the Tor Browser has no plugins installed

  Scenario: The persistent Tor Browser directory is usable
    Given Tails has booted without network from a USB drive with a persistent partition and stopped at Tails Greeter's login screen
    And the network is plugged
    When I enable persistence with password "asdf"
    And I log in to a new session
    And Tails is running from USB drive "current"
    And Tor is ready
    And available upgrades have been checked
    And all notifications have disappeared
    Then the persistent Tor Browser directory exists
    And there is a GNOME bookmark for the persistent Tor Browser directory
    When I start the Tor Browser
    And the Tor Browser has started and loaded the startup page
    And I can save the current page as "index.html" to the persistent Tor Browser directory
    When I open the address "file:///home/amnesia/Persistent/Tor Browser/index.html" in the Tor Browser
    Then I see "TorBrowserSavedStartupPage.png" after at most 10 seconds
    And I can print the current page as "output.pdf" to the persistent Tor Browser directory

  Scenario: Persistent browser bookmarks
    Given Tails has booted without network from a USB drive with a persistent partition and stopped at Tails Greeter's login screen
    And Tails is running from USB drive "current"
    And the boot device has safe access rights
    And I enable persistence with password "asdf"
    And I log in to a new session
    And the Tails desktop is ready
    And all notifications have disappeared
    And all persistence presets are enabled
    And all persistent filesystems have safe access rights
    And all persistence configuration files have safe access rights
    And all persistent directories have safe access rights
    And I start the Tor Browser in offline mode
    And the Tor Browser has started in offline mode
    And I add a bookmark to eff.org in the Tor Browser
    And I warm reboot the computer
    And the computer reboots Tails
    And I enable read-only persistence with password "asdf"
    And I log in to a new session
    And the Tails desktop is ready
    And I start the Tor Browser in offline mode
    And the Tor Browser has started in offline mode
    Then the Tor Browser has a bookmark to eff.org
