@product
Feature: Virtualization support

  Scenario: VirtualBox guest modules are available
    Given I have started Tails from DVD without network and logged in
    When Tails has booted a 64-bit kernel
    Then the VirtualBox guest modules are available
