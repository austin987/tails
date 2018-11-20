@product @check_tor_leaks

Feature: Additional software
  As a Tails user
  I may want to install softwares not shipped in Tails
  And have them installed automatically when I enable persistence in the Greeter

  # An issue with this feature is that scenarios depend on each
  # other. When editing this feature, make sure you understand these
  # dependencies (which are documented below).

  Scenario: I am warned I can not use Additional Software when I start Tails from a DVD and install a package
    Given I have started Tails from DVD and logged in with an administration password and the network is connected
    And I update APT using apt
    When I install "sslh" using apt
    Then I am notified I can not use Additional Software for "sslh"
    And I can open the Additional Software documentation from the notification link

  # Here we install the sslh package to test if debconf does not prevent
  # Additional Software from automatically installing packages.
  Scenario: I set up Additional Software when installing a package without persistent partition and the package is installed next time I start Tails
    Given I start Tails from a freshly installed USB drive with an administration password and the network is plugged and I login
    And I update APT using apt
    And I install "sslh" using apt
    Then I am proposed to create an Additional Software persistence for the "sslh" package
    And I create the Additional Software persistence
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    And Additional Software is correctly configured for package "sslh"
    And the package "sslh" is installed after Additional Software has been started

  # Depends on scenario: I set up Additional Software when installing a package without persistent partition and the package is installed next time I start Tails
  Scenario: No Additional Software notification is displayed when I install packages in a Tails session with locked down persistence
    Given a computer
    And I start Tails from USB drive "__internal" and I login with an administration password
    And I update APT using apt
    When I install "makepp" using apt
    Then the Additional Software dpkg hook has been run for package "makepp" and doesn't notify me as the persistence is locked
    And the package "makepp" is installed

  # Depends on scenario: I set up Additional Software when installing a package without persistent partition and the package is installed next time I start Tails
  Scenario: My Additional Software list is configurable through a GUI or through notifications when I install or remove packages with APT or Synaptic
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    When I uninstall "sslh" using apt
    And I accept removing "sslh" from Additional Software
    Then "sslh" is not in the list of Additional Software
    When I start Synaptic
    And I update APT using Synaptic
    And I install "cowsay" using Synaptic
    And I accept adding "cowsay" to Additional Software
    Then Additional Software is correctly configured for package "cowsay"
    When I uninstall "cowsay" using apt
    And I refuse removing "cowsay" from Additional Software
    Then Additional Software is correctly configured for package "cowsay"
    When I start "Additional Software" via GNOME Activities Overview
    And I remove "cowsay" from the list of Additional Software using Additional Software GUI
    Then "cowsay" is not in the list of Additional Software
    When I install "cowsay" using apt
    And I refuse adding "cowsay" to Additional Software
    Then "cowsay" is not in the list of Additional Software

  # Depends on scenario: Packages I remove from Additional Software through the GUI are not in the Additional Software list anymore
  # See https://tails.boum.org/blueprint/additional_software_packages/offline_mode/#incomplete-online-upgrade for high level logic
  Scenario: Recovering in offline mode after Additional Software previously failed to upgrade and then succeed to upgrade when online
    Given a computer
    And I start Tails from USB drive "__internal" and I login with persistence enabled and an administration password
    And I configure APT to prefer an old version of cowsay
    When I install an old version "3.03+dfsg2-1" of the cowsay package using apt
    And I accept adding "cowsay" to Additional Software
    And Additional Software is correctly configured for package "cowsay"
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged
    And I enable persistence
    # We need to add back this custom APT source for the Additional Software
    # install step, as it was not saved in persistence
    And I configure APT to prefer an old version of cowsay
    And I log in to a new session
    And the package "cowsay" installed version is "3.03+dfsg2-1" after Additional Software has been started
    And I revert the APT tweaks that made it prefer an old version of cowsay
    # We remove the newest package after it has been downloaded and before
    # it is installed, so that the upgrade process fails
    And I prepare the Additional Software upgrade process to fail
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And I see the "The upgrade of your additional software failed" notification after at most 300 seconds
    And I can open the Additional Software configuration window from the notification
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged
    And I enable persistence
    # We need to add back this custom APT source for the Additional Software
    # install step, as it was not saved in persistence
    And I configure APT to prefer an old version of cowsay
    And I log in to a new session
    And the package "cowsay" installed version is "3.03+dfsg2-1" after Additional Software has been started
    And I revert the APT tweaks that made it prefer an old version of cowsay
    And the network is plugged
    And Tor is ready
    Then the Additional Software upgrade service has started
    And the package "cowsay" installed version is newer than "3.03+dfsg2-1"

  # Depends on scenario: I set up Additional Software when installing a package without persistent partition and the package is installed next time I start Tails
  Scenario: I am notified when Additional Software fails to install a package
    Given a computer
    And I start Tails from USB drive "__internal" with network unplugged
    And I enable persistence
    # Trying to catch the notification at desktop startup is racy, so let's
    # start the installation service only once the desktop has settled.
    And I disable the Additional Software installation service
    And I log in to a new session
    And all notifications have disappeared
    And I remove the "cowsay" deb files from the APT cache
    And I start the Additional Software installation service
    Then I see the "The installation of your additional software failed" notification after at most 300 seconds
    And I can open the Additional Software log file from the notification
    And the package "cowsay" is not installed
