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
    When the network is plugged
    And Tor is ready
    Then DuckDuckGo is the default search engine
    When I enable the screen keyboard
    Then the screen keyboard works in Tor Browser
    And the screen keyboard works in Thunderbird
    And the layout of the screen keyboard is set to "<osk_layout>"

    # This list has to be kept in sync' with our list of tier-1 languages:
    #   https://tails.boum.org/contribute/how/translate/#tier-1-languages

    # Known issues, that this step effectively verifies are still present:
    #  - Not all localized layouts exist in the GNOME screen keyboard: #8444
    #  - Arabic's layout should be "ara": #12638
    Examples:
      | language   | start_accel | layout | osk_layout |
      | Arabic     | s           | us     | us         |
      | Chinese    | s           | cn     | us         |
      | English    | s           | us     | us         |
      | French     | d           | fr     | fr         |
      | German     | s           | de     | de         |
      | Hindi      | s           | in     | us         |
      | Indonesian | s           | id     | us         |
      | Italian    | s           | it     | us         |
      | Persian    | s           | ir     | ir         |
      | Portuguese | s           | pt     | us         |
      | Russian    | s           | ru     | ru         |
      # | Turkish  | XXX: #17974 | tr                  |
      # | Spanish  | XXX: #17974 | es                  |
