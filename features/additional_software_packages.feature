@product @fragile

Feature: Additional software packages
  As a Tails user
  I may want to install softwares not shipped in Tails
  And have them installed automatically when I enable persistence in the Greeter

  Scenario: I am warned I can not use ASP when I boot Tails from a DVD and install a package
    Given I have started Tails from DVD and logged in with an administration password and the network is connected
    And I update APT using apt
    When I install "sslh" using apt
    Then I am notified I can not use ASP for "sslh"
    #And I can open the documentation from the notification link

  Scenario: I can set up and use ASP when I install a package in a Tails that has no persistent partition
    Given I have started Tails without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen
    And I set an administration password
    And I log in to a new session
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And I update APT using apt
    And I install "sl" using apt
    Then I am proposed to create an ASP persistence for the "sl" package
    And I create the ASP persistence
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    And the ASP persistence is correctly configured for package "sl"
    And the additional software package installation service has started
    And the package "sl" is installed

  Scenario: Packages I install with Synaptic and add to ASP are automatically installed
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I install "sslh" using Synaptic
    And I confirm when I am asked if I want to add "sslh" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service has started
    And the package "sslh" is installed

  Scenario: Packages I uninstall and accept to remove from ASP are not installed anymore
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I uninstall "sslh" using apt
    And I confirm when I am asked if I want to remove "sslh" from ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service has started
    And the package "sslh" is not installed

  Scenario: Packages I install but not do not add to ASP are not automatically installed
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I install "sslh" using apt
    And I deny when I am asked if I want to add "sslh" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service has started
    And the package "sslh" is not installed

  Scenario: Packages I have installed and added to ASP are upgraded when a network is available
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    # This step installs an old cowsay from a custom APT source
    When I install an old version "" of the "cowsay" package using apt
    And I confirm when I am asked if I want to add "cowsay" to ASP configuration
    # We have to remove the custom APT source so that cowsay gets updated at next boot
    And I remove the APT source for the old cowsay version
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    And the additional software package installation service has started
    And the package "cowsay" installed version is ""
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    # XXX: AFAIK there's no user notification for the upgrade service
    #Then I am notified that the installation succeeded
    Then the additional software package upgrade service has started
    And the package "cowsay" installed version is newer than ""

  Scenario: Packages I uninstall through ASP GUI are not installed anymore
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    And the additional software package installation service has started
    And I am notified that the installation succeeded
    And the package "cowsay" is installed
    And I start the ASP GUI
    And I remove "cowsay" from the list of ASP packages
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service has started
    And the package "cowsay" is not installed

  Scenario: Recovering in offline mode after ASP previously failed to upgrade a package
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I install an old version "" of the "cowsay" package using apt
    And I confirm when I am asked if I want to add "cowsay" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    And the additional software package installation service has started
    And the package "cowsay" installed version is ""
    And I prepare the ASP upgrade process to fail
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And the additional software package upgrade service has started
    And I am notified the "ASP upgrade service" failed
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service has started
    And the package "cowsay" is installed

  Scenario: I am notified when ASP fails to install a package
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I install "vrms" using apt
    And I confirm when I am asked if I want to add "vrms" to ASP configuration
    And I remove the "vrms" deb file from the APT cache
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then I am notified the "ASP installation service" failed
    And the package "vrms" is not installed
