@product
Feature: Metadata Anonymization Toolkit
  As a Tails user
  I want to be able to remove leaky metadata from documents and media files

  # In this feature we cannot restore from snapshots since it's
  # incompatible with filesystem shares.

  Scenario: MAT can clean a PDF file
    Given a computer
    And I setup a filesystem share containing a sample PDF
    And I start Tails from DVD with network unplugged and I login
    Then MAT can clean some sample PDF file
