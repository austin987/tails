@product
Feature: Virtualization support

  Scenario: VirtualBox guest modules are available
    Given a computer
    When I start Tails from DVD with network unplugged and I login
    Then the VirtualBox guest modules are available
