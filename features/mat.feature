#11901: mat does not clean PDF files anymore
@product @fragile
Feature: Metadata Anonymization Toolkit
  As a Tails user
  I want to be able to remove leaky metadata from documents and media files

  Scenario: MAT can clean a PDF file
    Given I have started Tails from DVD without network and logged in
    And I plug and mount a USB drive containing a sample PDF
    Then MAT can clean some sample PDF file
