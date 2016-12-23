@product
Feature: Metadata Anonymization Toolkit
  As a Tails user
  I want to be able to remove leaky metadata from documents and media files

  Scenario: MAT can clean a PNG file
    Given a computer
    And I setup a filesystem share containing a sample PNG
    And I start Tails from DVD with network unplugged and I login
    Then MAT can clean some sample PNG file
