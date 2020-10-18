@product
Feature: Localization
  As a Tails user
  I want Tails to be localized in my native language
  And various Tails features should still work

  @doc
  Scenario: The Report an Error launcher opens the support documentation in supported non-English locales
    Given I have started Tails from DVD without network and stopped at Tails Greeter's login screen
    And I log in to a new session in German with accelerator "s"
    When I double-click on the Report an Error launcher on the desktop
    Then the support documentation page opens in Tor Browser

  Scenario: The Unsafe Browser can be used in all languages supported in Tails
    Given I have started Tails from DVD and logged in and the network is connected
    And I magically allow the Unsafe Browser to be started
    Then the Unsafe Browser works in all supported languages

  Scenario Outline: Tails is localized for every tier-1 language
    Given I have started Tails from DVD without network and stopped at Tails Greeter's login screen
    When I log in to a new session in <language> with accelerator "<start_accel>"
    Then the keyboard layout is set to "<layout>"

    # This list has to be kept in sync' with our list of tier-1 languages:
    # https://tails.boum.org/contribute/how/translate/#tier-1-languages
    Examples:
      | language   | start_accel | layout |
      | Chinese    | s           | cn     |
      | English    | s           | us     |
      | French     | d           | fr     |
      | German     | s           | de     |
      | Hindi      | s           | in     |
      | Indonesian | s           | id     |
      | Italian    | s           | it     |
      | Persian    | s           | ir     |
      | Portuguese | s           | pt     |
      | Russian    | s           | ru     |
      # | Turkish  | XXX: #17974 | tr                  |
      # | Arabic   | s             | ara (XXX: #12638) |
      # | Spanish  | XXX: #17974 | es                  |
