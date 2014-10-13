@product
Feature: Using Evince
  As a Tails user
  I want to view and print PDF files in Evince
  And AppArmor should prevent Evince from doing dangerous things

  Background:
    Given a computer
    And I start Tails from DVD with network unplugged and I login
    And I save the state so the background can be restored next scenario

  Scenario: I can view and print a PDF file stored in /usr/share
    When I open "/usr/share/cups/data/default-testpage.pdf" with Evince
    Then I see "CupsTestPage.png" after at most 10 seconds
    And I can print the current document to "/home/amnesia/output.pdf"

  Scenario: I can view and print a PDF file stored in non-persistent /home/amnesia
    Given I copy "/usr/share/cups/data/default-testpage.pdf" to "/home/amnesia" as user "amnesia"
    When I open "/home/amnesia/default-testpage.pdf" with Evince
    Then I see "CupsTestPage.png" after at most 10 seconds
    And I can print the current document to "/home/amnesia/output.pdf"

  Scenario: I cannot view a PDF file stored in non-persistent /home/amnesia/.gnupg
    Given I copy "/usr/share/cups/data/default-testpage.pdf" to "/home/amnesia/.gnupg" as user "amnesia"
    When I try to open "/home/amnesia/.gnupg/default-testpage.pdf" with Evince
    Then I see "EvinceUnableToOpen.png" after at most 10 seconds

  @keep_volumes
  Scenario: Installing Tails on a USB drive, creating a persistent partition, copying PDF files to it
    Given the USB drive "current" contains Tails with persistence configured and password "asdf"
    And a computer
    And I start Tails from USB drive "current" with network unplugged and I login with persistence password "asdf"
    And I copy "/usr/share/cups/data/default-testpage.pdf" to "/home/amnesia/Persistent" as user "amnesia"
    Then the file "/home/amnesia/Persistent/default-testpage.pdf" exists
    And I copy "/usr/share/cups/data/default-testpage.pdf" to "/home/amnesia/.gnupg" as user "amnesia"
    Then the file "/home/amnesia/.gnupg/default-testpage.pdf" exists
    And I shutdown Tails and wait for the computer to power off

  @keep_volumes
  Scenario: I can view and print a PDF file stored in persistent /home/amnesia/Persistent
    Given a computer
    And I start Tails from USB drive "current" with network unplugged and I login with persistence password "asdf"
    When I open "/home/amnesia/Persistent/default-testpage.pdf" with Evince
    Then I see "CupsTestPage.png" after at most 10 seconds
    And I can print the current document to "/home/amnesia/Persistent/output.pdf"

  @keep_volumes
  Scenario: I cannot view a PDF file stored in persistent /home/amnesia/.gnupg
    Given a computer
    When I start Tails from USB drive "current" with network unplugged and I login with persistence password "asdf"
    And I try to open "/home/amnesia/.gnupg/default-testpage.pdf" with Evince
    Then I see "EvinceUnableToOpen.png" after at most 10 seconds

