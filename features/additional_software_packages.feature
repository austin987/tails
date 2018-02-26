@product @fragile

Feature: Additional software packages
  As a Tails user
  I may want to install softwares not shipped in Tails
  And have them installed automatically when I enable persistence in the Greeter

  Scenario: ASP persistence can be set up and used when installing a package in Tails without persistence
    Given I have started Tails without network from a USB drive and logged in with an administration password
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    # This is required to use APT in the test suite as explained in
    # commit e2510fae79870ff724d190677ff3b228b2bf7eac
    And I configure APT to use non-onion sources
    And I update APT using apt
    # We have to save the non-onion APT sources in persistence, so
    # that on next boot the additional software packages service has
    # the right APT indexes to install the package we want.
    And I make my current APT sources persistent
    And I install "sl" using APT
    Then I am proposed to create an ASP persistence
    And I create the persistence
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    And the additional software package installation service is run
    And the package "sl" is installed

  Scenario: Additional software packages are installed even without network
    When I install "sslh" using apt
    And I confirm when I am asked if I want to add "sslh" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service is run
    And I am notified that the package "sslh" is installed
    And the package "sslh" is installed

  Scenario: Packages installed with Synaptic and added to ASP are automatically installed
    When I install "sslh" using synaptic
    And I confirm when I am asked if I want to add "sslh" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service is run
    And I am notified that the package "sslh" is installed
    And the package "sslh" is installed

  Scenario: Packages installed with APT but not added to ASP are not automatically installed
    When I install "sslh" using apt
    And I deny when I am asked if I want to add "sslh" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service is run
    And the package "sslh" is not installed

  Scenario: Packages installed with ASP are upgraded when a network is available
    When I install an old version "" if the "cowsay" package using apt
    And I confirm when I am asked if I want to add "cowsay" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" and I login with persistence enabled
    Then the additional software package installation service is run
    And the package "cowsay" installed version is ""
    And the additional software package upgrade service is run
    And the package "cowsay" installed version is newer than ""

  Scenario: Recovering in offline mode after a previous failed ASP upgrade
    When I install an old version "" if the "cowsay" package using apt
    And I confirm when I am asked if I want to add "cowsay" to ASP configuration
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    And the additional software package installation service is run
    And the package "cowsay" installed version is ""
    And I prepare the ASP upgrade process to fail
    And the network is plugged
    And Tor is ready
    And all notifications have disappeared
    And available upgrades have been checked
    And the additional software package upgrade service is run
    And I am notified the "ASP upgrade service" failed
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service is run
    And the package "cowsay" is installed

  Scenario: I am warned I can not use ASP when booting Tails from DVD and installing a package
    Given I have started Tails from DVD and logged in with an administration password and the network is connected
    # This is required to use APT in the test suite as explained in
    # commit e2510fae79870ff724d190677ff3b228b2bf7eac
    And I configure APT to use non-onion sources
    And I update APT using apt
    When I install "sslh" using apt
    Then I am said I can not use ASP

  Scenario: I am notified when ASP fails to install a package
    When I install "sslh" using apt
    And I confirm when I am asked if I want to add "sslh" to ASP configuration
    And I remove the "sslh" deb file from the APT cache
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the ASP installation service is run
    And I am notified the "ASP installation service" failed
    And the package "sslh" is not installed

  Scenario: Removing a package from ASP through APT
    When I uninstall "sl" using apt
    And I confirm when I am asked if that I don't want "sl" to be installed by ASP
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    Then the additional software package installation service is run
    And the package "sl" is not installed

  #Scenario: Removing a package from ASP through its GUI
