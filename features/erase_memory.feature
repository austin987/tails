@product
Feature: System memory erasure on shutdown
  As a Tails user
  when I shutdown Tails
  I want the system memory to be free from sensitive data.

# These tests rely on the Linux kernel's memory poisoning features.
# The feature is called "on shutdown" as this is the security guarantee
# we document, but in practice we have no good way to test behavior on shutdown
# per-se (known patterns allocated in memory will be erased _before_ shutdown
# by the kernel). So we test that some important bits of memory are erased
# _before_ shutdown.

  Scenario: Erasure of memory freed by killed userspace processes
    Given I have started Tails from DVD without network and logged in
    And I prepare Tails for memory erasure tests
    When I fill the guest's memory with a known pattern and the allocating processes get killed
    Then I find very few patterns in the guest's memory

  Scenario: Erasure of tmpfs data on unmount
    Given I have started Tails from DVD without network and logged in
    And I prepare Tails for memory erasure tests
    And I find very few patterns in the guest's memory
    When I mount a 128 MiB tmpfs on "/mnt" and fill it with a known pattern
    Then patterns cover at least 99% of the tmpfs size in the guest's memory
    When I umount "/mnt"
    Then I find very few patterns in the guest's memory
