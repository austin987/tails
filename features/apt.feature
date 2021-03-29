@product
Feature: APT sources are correctly configured
  As a Tails user
  I want APT to be configured to use hidden services

  Scenario: APT sources are configured correctly
    Given a computer
    And I start Tails from DVD with network unplugged and genuine APT sources
    Then the only hosts in APT sources are "cdn-fastly.deb.debian.org,umjqavufhoix3smyq6az2sx4istmuvsgmz4bq5u5x56rnayejoo6l2qd.onion,sdscoq7snqtznauu.onion"
    And no proposed-updates APT suite is enabled
    And no experimental APT suite is enabled for deb.torproject.org
    And if releasing, no unversioned Tails APT source is enabled
    And if releasing, the tagged Tails APT source is enabled
