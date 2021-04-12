@product
Feature: Browsing the web using the Unsafe Browser
  As a Tails user
  when I browse the web using the Unsafe Browser
  I should have direct access to the web

  Scenario: The Unsafe Browser is disabled by default
    Given I have started Tails from DVD and logged in and the network is connected
    When I try to start the Unsafe Browser
    Then the Unsafe Browser complains that it is disabled

  Scenario: The Unsafe Browser can access the LAN
    Given I have started Tails from DVD and logged in with the Unsafe Browser enabled and the network is connected
    And a web server is running on the LAN
    When I successfully start the Unsafe Browser
    And I open a page on the LAN web server in the Unsafe Browser
    Then I see "UnsafeBrowserHelloLANWebServer.png" after at most 20 seconds

  Scenario: Starting the Unsafe Browser works as it should
    Given I have started Tails from DVD and logged in with the Unsafe Browser enabled and the network is connected
    When I successfully start the Unsafe Browser
    Then the Unsafe Browser runs as the expected user
    And the Unsafe Browser has a red theme
    And the Unsafe Browser shows a warning as its start page
    And the Unsafe Browser has no plugins installed
    And the Unsafe Browser has no add-ons installed
    And the Unsafe Browser has only Firefox's default bookmarks configured
    And the Unsafe Browser uses all expected TBB shared libraries

  Scenario: The Unsafe Browser can load a web page
    Given I have started Tails from DVD and logged in with the Unsafe Browser enabled and the network is connected
    When I successfully start the Unsafe Browser
    When I open the Tails homepage in the Unsafe Browser
    Then the Tails homepage loads in the Unsafe Browser

  Scenario: Closing the Unsafe Browser shows a stop notification and properly tears down the chroot
    Given I have started Tails from DVD and logged in with the Unsafe Browser enabled and the network is connected
    When I successfully start the Unsafe Browser
    And I close the Unsafe Browser
    Then I see the "Shutting down the Unsafe Browser..." notification after at most 60 seconds
    And the Unsafe Browser chroot is torn down

  Scenario: Starting a second instance of the Unsafe Browser results in an error message being shown
    Given I have started Tails from DVD and logged in with the Unsafe Browser enabled and the network is connected
    When I successfully start the Unsafe Browser
    # Wait for whatever facility the GNOME Activities Overview uses to
    # learn about which applications are running to "settle". Without
    # this sleep, it is confused and it's impossible to start a new
    # instance (it will just switch to the one we already started).
    And I wait 10 seconds
    And I start the Unsafe Browser
    Then I see a warning about another instance already running

  Scenario: The Unsafe Browser is not allowed to use a local proxy
    Given I have started Tails from DVD and logged in with the Unsafe Browser enabled and the network is connected
    When I configure the Unsafe Browser to use a local proxy
    And I successfully start the Unsafe Browser
    And I open the Tails homepage in the Unsafe Browser
    Then I see "BrowserProxyRefused.png" after at most 60 seconds

  Scenario: The Unsafe Browser only makes user-initiated connections to the Internet
    Given I have started Tails from DVD and logged in with the Unsafe Browser enabled and the network is connected
    And I capture all network traffic
    And Tor is ready
    And I configure the Unsafe Browser to check for updates more frequently
    But checking for updates is disabled in the Unsafe Browser's configuration
    When I successfully start the Unsafe Browser
    Then the Unsafe Browser has started
    And I wait 120 seconds
    And the clearnet user has not sent packets out to the Internet
    And all Internet traffic has only flowed through Tor

  Scenario: The Unsafe Browser cannot be started when I am offline
    Given I have started Tails from DVD without network and logged in with the Unsafe Browser enabled
    When I start the Unsafe Browser
    And I see and accept the Unsafe Browser start verification
    Then I am told I cannot start the Unsafe Browser when I am offline
