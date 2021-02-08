@product
Feature: Hardening features

  Scenario: AppArmor is enabled and has enforced profiles
    Given I have started Tails from DVD without network and logged in
    Then AppArmor is enabled
    And some AppArmor profiles are enforced

  Scenario: The tor process should be confined with Seccomp
    Given I have started Tails from DVD without network and logged in
    And the network is plugged
    And Tor is ready
    Then Tor is confined with Seccomp

