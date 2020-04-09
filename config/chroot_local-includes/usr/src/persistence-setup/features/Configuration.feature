Feature: configuration model
  As a Tails developer,
  when I work on tails-persistence-setup,
  I want to ensure the configuration model works correctly.

  Scenario: read from non-existing file
    Given the file does not exist
    When I create a ConfigFile object
    Then the file should be created
    And the list of lines in the file object should be empty

  Scenario: read from empty file
    Given the file is empty
    When I create a ConfigFile object
    Then the list of lines in the file object should be empty

  Scenario: read from file that has a valid one-column line
    Given the file has a valid one-column line
    When I create a ConfigFile object
    Then the list of options should be empty

  Scenario: read from file that has a line with source option set
    Given the file has a valid line with options 'source=bla'
    When I create a ConfigFile object
    Then the options list should contain 1 element

  Scenario: read from file that has only a commented-out line
    Given the file has only a commented-out line
    When I create a ConfigFile object
    Then the list of lines in the file object should be empty

  Scenario: read from file that contains two valid two-columns lines and output
    Given the file has two valid two-columns lines
    When I create a ConfigFile object
    Then the output string should contain 2 lines

  Scenario: read and write file that contains two valid two-columns lines
    Given the file has two valid two-columns lines
    When I create a ConfigFile object
    And I write in-memory configuration to file
    Then the file should contain 2 lines

  Scenario: read file that contains a line with options
    Given the file has a valid line with options 'optA,optB'
    When I create a ConfigFile object
    Then the options list should contain 2 elements
    And 'optA' should be part of the options list
    And 'optB' should be part of the options list

  Scenario: merge empty file with default presets
    Given the file is empty
    When I merge the presets and the file
    Then the list of configuration atoms should contain 12 elements
    And there should be 1 enabled configuration line

  Scenario: merge non-empty file with enabled-by-default preset in
    Given the file has the following content
      """
      /home/amnesia/Persistent source=Persistent
      /home/amnesia/.myapp source=myapp
      """
    When I merge the presets and the file
    Then the list of configuration atoms should contain 13 elements
    And there should be 2 enabled configuration lines

  Scenario: merge non-empty file with disabled-by-default preset in
    Given the file has the following content
      """
      /home/amnesia/.gnupg source=gnupg
      /home/amnesia/.myapp source=myapp
      """
    When I merge the presets and the file
    Then the list of configuration atoms should contain 13 elements
    And there should be 3 enabled configuration lines
