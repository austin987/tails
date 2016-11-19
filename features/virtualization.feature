@product
Feature: Virtualization support

  Scenario: VirtualBox guest modules are available
    Given a computer
    And the computer is an old pentium without the PAE extension
    And I start Tails from DVD with network unplugged and I login
    When Tails has booted a 32-bit kernel
    Then the VirtualBox guest modules are available
