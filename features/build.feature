@source
Feature: custom APT sources to build branches
  As a Tails developer, when I build Tails, I'd be happy if
  the proper APT sources were automatically picked depending
  on which Git branch I am working on.

  Scenario: build from a tagged stable branch
    Given Tails 0.10 has been released
    And last released version mentioned in debian/changelog is 0.10
    And I am working on the stable branch
    When I run tails-custom-apt-sources
    Then I should see the '0.10' suite

  Scenario: build from a bugfix branch for a stable release
    Given Tails 0.10 has been released
    And last released version mentioned in debian/changelog is 0.10
    And I am working on the bugfix/disable_gdomap branch based on 0.10
    When I run tails-custom-apt-sources
    Then I should see the '0.10' suite
    And I should see the 'bugfix-disable-gdomap' suite

  Scenario: build from an untagged testing branch
    Given I am working on the testing branch
    And last released version mentioned in debian/changelog is 0.11
    And Tails 0.11 has not been released yet
    When I run tails-custom-apt-sources
    Then I should see the 'testing' suite
    And I should not see '0.11' suite

  Scenario: build from a tagged testing branch
    Given I am working on the testing branch
    And last released version mentioned in debian/changelog is 0.11
    And Tails 0.11 has been released
    When I run tails-custom-apt-sources
    Then I should see the '0.11' suite
    And I should not see 'testing' suite

  Scenario: build a release candidate from a tagged testing branch
    Given I am working on the testing branch
    And Tails 0.11 has been released
    And last released version mentioned in debian/changelog is 0.12~rc1
    And Tails 0.12-rc1 has been tagged
    When I run tails-custom-apt-sources
    Then I should see the '0.12-rc1' suite
    And I should not see 'testing' suite

  Scenario: build from the devel branch
    Given I am working on the devel branch
    When I run tails-custom-apt-sources
    Then I should see the 'devel' suite

  Scenario: build from the experimental branch
    Given I am working on the experimental branch
    When I run tails-custom-apt-sources
    Then I should see the 'experimental' suite

  Scenario: build from a feature branch based on devel
    Given I am working on the feature/icedove branch based on devel
    When I run tails-custom-apt-sources
    Then I should see the 'devel' suite
    And I should see the 'feature-icedove' suite

  Scenario: build from a feature branch based on devel with dots in its name
    Given I am working on the feature/live-boot-3.x branch based on devel
    When I run tails-custom-apt-sources
    Then I should see the 'devel' suite
    And I should see the 'feature-live-boot-3.x' suite
