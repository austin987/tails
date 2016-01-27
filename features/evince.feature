@product
Feature: Using Evince
  As a Tails user
  I want to view and print PDF files in Evince
  And AppArmor should prevent Evince from doing dangerous things

  #10775, #10994
  @fragile
  Scenario: I can view and print a PDF file stored in /usr/share
    Given I have started Tails from DVD without network and logged in
    When I open "/usr/share/cups/data/default-testpage.pdf" with Evince
    Then I see "CupsTestPage.png" after at most 20 seconds
    And I can print the current document to "/home/amnesia/output.pdf"

  #10994
  @fragile
  Scenario: I can view and print a PDF file stored in non-persistent /home/amnesia
    Given I have started Tails from DVD without network and logged in
    And I copy "/usr/share/cups/data/default-testpage.pdf" to "/home/amnesia" as user "amnesia"
    When I open "/home/amnesia/default-testpage.pdf" with Evince
    Then I see "CupsTestPage.png" after at most 20 seconds
    And I can print the current document to "/home/amnesia/output.pdf"

  Scenario: I cannot view a PDF file stored in non-persistent /home/amnesia/.gnupg
    Given I have started Tails from DVD without network and logged in
    And I copy "/usr/share/cups/data/default-testpage.pdf" to "/home/amnesia/.gnupg" as user "amnesia"
    Then the file "/home/amnesia/.gnupg/default-testpage.pdf" exists
    And the file "/lib/live/mount/overlay/home/amnesia/.gnupg/default-testpage.pdf" exists
    And the file "/live/overlay/home/amnesia/.gnupg/default-testpage.pdf" exists
    Given I start monitoring the AppArmor log of "/usr/bin/evince"
    When I try to open "/home/amnesia/.gnupg/default-testpage.pdf" with Evince
    Then I see "EvinceUnableToOpen.png" after at most 10 seconds
    And AppArmor has denied "/usr/bin/evince" from opening "/home/amnesia/.gnupg/default-testpage.pdf"
    When I close Evince
    Given I restart monitoring the AppArmor log of "/usr/bin/evince"
    When I try to open "/lib/live/mount/overlay/home/amnesia/.gnupg/default-testpage.pdf" with Evince
    Then I see "EvinceUnableToOpen.png" after at most 10 seconds
    And AppArmor has denied "/usr/bin/evince" from opening "/lib/live/mount/overlay/home/amnesia/.gnupg/default-testpage.pdf"
    When I close Evince
    Given I restart monitoring the AppArmor log of "/usr/bin/evince"
    When I try to open "/live/overlay/home/amnesia/.gnupg/default-testpage.pdf" with Evince
    Then I see "EvinceUnableToOpen.png" after at most 10 seconds
    # Due to our AppArmor aliases, /live/overlay will be treated
    # as /lib/live/mount/overlay.
    And AppArmor has denied "/usr/bin/evince" from opening "/lib/live/mount/overlay/home/amnesia/.gnupg/default-testpage.pdf"

  #10720: Tails Installer freezes on Jenkins
  @fragile
  Scenario: I can view and print a PDF file stored in persistent /home/amnesia/Persistent
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    And I copy "/usr/share/cups/data/default-testpage.pdf" to "/home/amnesia/Persistent" as user "amnesia"
    Then the file "/home/amnesia/Persistent/default-testpage.pdf" exists
    When I open "/home/amnesia/Persistent/default-testpage.pdf" with Evince
    Then I see "CupsTestPage.png" after at most 20 seconds
    And I can print the current document to "/home/amnesia/Persistent/output.pdf"

  #10720: Tails Installer freezes on Jenkins
  @fragile
  Scenario: I cannot view a PDF file stored in persistent /home/amnesia/.gnupg
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    And I copy "/usr/share/cups/data/default-testpage.pdf" to "/home/amnesia/.gnupg" as user "amnesia"
    Then the file "/home/amnesia/.gnupg/default-testpage.pdf" exists
    Given I start monitoring the AppArmor log of "/usr/bin/evince"
    And I try to open "/home/amnesia/.gnupg/default-testpage.pdf" with Evince
    Then I see "EvinceUnableToOpen.png" after at most 10 seconds
    And AppArmor has denied "/usr/bin/evince" from opening "/home/amnesia/.gnupg/default-testpage.pdf"
