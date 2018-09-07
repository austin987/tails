@product

Feature: Additional software packages
  As a Tails user
  I may want to install softwares not shipped in Tails
  And have them installed automatically when I enable persistence in the Greeter

  Scenario: I am warned I can not use ASP when I boot Tails from a DVD and install a package
    Given I have started Tails from DVD and logged in with an administration password and the network is connected
    And I update APT using apt
    When I install "sslh" using apt
    Then I am notified I can not use ASP for "sslh"
    And I can open the documentation from the notification link

  @check_tor_leaks
  Scenario: I can set up and use ASP when I install a package in a Tails that has no persistent partition
    Given I have started Tails without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen
    And I set an administration password
    And I log in to a new session
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And I update APT using apt
    And I install "sslh" using apt
    Then I am proposed to create an ASP persistence for the "sslh" package
    And I create the ASP persistence
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    And the ASP persistence is correctly configured for package "sslh"
    And the additional software package installation service has started
    And the package "sslh" is installed

  @check_tor_leaks
  Scenario: I can install packages in a Tails session with locked down persistence without being annoyed by ASP
    Given a computer
    And I start Tails from USB drive "__internal" and I login with an administration password
    And I update APT using apt
    When I install "cowsay" using apt
    Then ASP has been started for "cowsay" and shuts up because the persistence is locked
    And the package "cowsay" is installed

  #12586
  @check_tor_leaks
  Scenario: Packages I install with Synaptic and add to ASP are automatically installed
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    And I start Synaptic
    And I update APT using Synaptic
    When I install "cowsay" using Synaptic
    And I confirm when I am asked if I want to add "cowsay" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service has started
    And the package "cowsay" is installed

  Scenario: Packages I uninstall and accept to remove from ASP are not installed anymore
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I uninstall "cowsay" using apt
    And I confirm when I am asked if I want to remove "cowsay" from ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service has started
    And the package "cowsay" is not installed

  Scenario: Packages I uninstall but don't want to remove from ASP are automatically installed
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I uninstall "sslh" using apt
    And I deny when I am asked if I want to remove "sslh" from ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service has started
    And the package "sslh" is installed

  @check_tor_leaks
  Scenario: Packages I install but not do not add to ASP are not automatically installed
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I install "sl" using apt
    And I deny when I am asked if I want to add "sl" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service has started
    And the package "sl" is not installed

 @check_tor_leaks
  Scenario: Packages I have installed and added to ASP are upgraded when a network is available
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    # This step installs an old cowsay from a custom APT source
    When I install an old version "3.03+dfsg2-1" of the cowsay package using apt
    And I confirm when I am asked if I want to add "cowsay" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged
    And I enable persistence
    # We need to add back the custom APT source for the ASP install step, as it
    # was not saved in persistence
    And I configure APT with a custom source for the old version of cowsay
    And I log in to a new session
    And the additional software package installation service has started
    And the package "cowsay" installed version is "3.03+dfsg2-1"
    # And then to remove it so that cowsay gets updated
    And I remove the custom APT source for the old cowsay version
    And the network is plugged
    And Tor is ready
    Then the additional software package upgrade service has started
    And the package "cowsay" installed version is newer than "3.03+dfsg2-1"

  Scenario: Packages I uninstall through ASP GUI are not installed anymore
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    And the additional software package installation service has started
    And the package "cowsay" is installed
    And I start "Additional Software" via GNOME Activities Overview
    And I remove "cowsay" from the list of ASP packages
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service has started
    And the package "cowsay" is not installed

  @check_tor_leaks
  Scenario: Recovering in offline mode after ASP previously failed to upgrade a package
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I install an old version "3.03+dfsg2-1" of the cowsay package using apt
    And I confirm when I am asked if I want to add "cowsay" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged
    And I enable persistence
    # We need to add back the custom APT source for the ASP install step, as it
    # was not saved in persistence
    And I configure APT with a custom source for the old version of cowsay
    And I log in to a new session
    And the additional software package installation service has started
    And the package "cowsay" installed version is "3.03+dfsg2-1"
    # And then to remove it so that cowsay gets updated
    And I remove the custom APT source for the old cowsay version
    And I prepare the ASP upgrade process to fail
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And I see the "The upgrade of your additional software failed" notification after at most 300 seconds
    And I can open the ASP configuration from the notification
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged
    And I enable persistence
    # We need to add back the custom APT source for the ASP install step, as it
    # was not saved in persistence
    And I configure APT with a custom source for the old version of cowsay
    And I log in to a new session
    Then the additional software package installation service has started
    And the package "cowsay" installed version is "3.03+dfsg2-1"

  @check_tor_leaks
  Scenario: I am notified when ASP fails to install a package
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I install "vrms" using apt
    And I confirm when I am asked if I want to add "vrms" to ASP configuration
    And I remove the "vrms" deb file from the APT cache
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged
    And I enable persistence
    And I log in to a new session
    And all notifications have disappeared
    Then I see the "The installation of your additional software failed" notification after at most 300 seconds
    And I can open the ASP log file from the notification
    And the package "vrms" is not installed
