@product @check_tor_leaks

Feature: Additional software packages
  As a Tails user
  I may want to install softwares not shipped in Tails
  And have them installed automatically when I enable persistence in the Greeter

  # An issue with this feature is that scenarios depend on each
  # other. When editing this feature, make sure you understand these
  # dependencies (which are documented below).

  Scenario: I am warned I can not use ASP when I start Tails from a DVD and install a package
    Given I have started Tails from DVD and logged in with an administration password and the network is connected
    And I update APT using apt
    When I install "sslh" using apt
    Then I am notified I can not use Additional Software persistence for "sslh"
    And I open the Additional Software documentation from the notification link

  Scenario: I set up ASP when installing a package without persistent partition and the package is installed next time I start Tails
    Given I have started Tails without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen
    And I set an administration password
    And I log in to a new session
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And I update APT using apt
    And I install "sslh" using apt
    Then I am proposed to create an Additional Software persistence for the "sslh" package
    And I create the Additional Software persistence
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    And the Additional Software persistence is correctly configured for package "sslh"
    And the additional software package installation service has started
    And the package "sslh" is installed

  # Depends on scenario: I set up ASP when installing a package without persistent partition and the package is installed next time I start Tails
  Scenario: I install packages in a Tails session with locked down persistence without being annoyed by ASP
    Given a computer
    And I start Tails from USB drive "__internal" and I login with an administration password
    And I update APT using apt
    When I install "cowsay" using apt
    Then ASP has been started for "cowsay" and shuts up because the persistence is locked
    And the package "cowsay" is installed

  #12586
  # Depends on scenario: I set up ASP when installing a package without persistent partition and the package is installed next time I start Tails
  Scenario: Packages I install with Synaptic and add to ASP are automatically installed
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    And I start Synaptic
    And I update APT using Synaptic
    When I install "cowsay" using Synaptic
    And I accept adding "cowsay" to Additional Software persistence
    Then the Additional Software persistence is correctly configured for package "cowsay"
    And the package "cowsay" is installed

  # Depends on scenario: Packages I install with Synaptic and add to ASP are automatically installed
  Scenario: Packages I uninstall and accept to remove from ASP are not installed anymore
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I uninstall "cowsay" using apt
    And I accept removing "cowsay" from Additional Software persistence
    Then "cowsay" is not part of Additional Software persistence configuration

  # Depends on scenario: I set up ASP when installing a package without persistent partition and the package is installed next time I start Tails
  Scenario: Packages I remove but refuse removing from ASP are still automatically installed
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I uninstall "sslh" using apt
    And I refuse removing "sslh" from Additional Software persistence
    Then the Additional Software persistence is correctly configured for package "sslh"

  # Depends on scenario: I set up ASP when installing a package without persistent partition and the package is installed next time I start Tails
  Scenario: Packages I install but not do not add to ASP are not automatically installed
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I install "sl" using apt
    And I refuse adding "sl" to Additional Software persistence
    Then "sl" is not part of Additional Software persistence configuration

  # Depends on scenario: Packages I uninstall and accept to remove from ASP are not installed anymore
  Scenario: Recovering in offline mode after ASP previously failed to upgrade and then succeed to upgrade when online
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I install an old version "3.03+dfsg2-1" of the cowsay package using apt
    And I accept adding "cowsay" to Additional Software persistence
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged
    And I enable persistence
    # We need to add back the custom APT source for the ASP install step, as it
    # was not saved in persistence
    And I add a APT source which has the old version of cowsay
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
    And I open the Additional Software configuration window from the notification
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged
    And I enable persistence
    # We need to add back the custom APT source for the ASP install step, as it
    # was not saved in persistence
    And I add a APT source which has the old version of cowsay
    And I log in to a new session
    And the additional software package installation service has started
    And the package "cowsay" installed version is "3.03+dfsg2-1"
    # And then to remove it so that cowsay gets updated
    And I remove the custom APT source for the old cowsay version
    And the network is plugged
    And Tor is ready
    Then the additional software package upgrade service has started
    And the package "cowsay" installed version is newer than "3.03+dfsg2-1"

  # Depends on scenario: Recovering in offline mode after ASP previously failed to upgrade and then succeed to upgrade when online
  Scenario: Packages I uninstall through ASP GUI are not installed anymore
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    And the additional software package installation service has started
    And the package "cowsay" is installed
    And I start "Additional Software" via GNOME Activities Overview
    And I remove "cowsay" from the list of ASP using Additional Software
    Then "cowsay" is not part of Additional Software persistence configuration

  # Depends on scenario: I set up ASP when installing a package without persistent partition and the package is installed next time I start Tails
  Scenario: I am notified when ASP fails to install a package
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I install "vrms" using apt
    And I accept adding "vrms" to Additional Software persistence
    And I remove the "vrms" deb file from the APT cache
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged
    And I enable persistence
    And I log in to a new session
    And all notifications have disappeared
    Then I see the "The installation of your additional software failed" notification after at most 300 seconds
    And I open the Additional Software log file from the notification
    And the package "vrms" is not installed
