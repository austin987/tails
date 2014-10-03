@product
Feature: Using Totem
  As a Tails user
  I want to watch local and remote videos in Totem
  And AppArmor should prevent Totem from doing dangerous things

  # We cannot use Background to save a snapshot of an already booted
  # Tails here, due to bugs with filesystem shares vs. snapshots, as
  # explained in checks.feature.

  Background:
    Given I create sample videos

  Scenario: I can watch an MP4 video stored in non-persistent /home/amnesia
    Given a computer
    And I setup a filesystem share containing sample videos
    And I start Tails from DVD with network unplugged and I login
    And I copy the sample videos to "/home/amnesia" as user "amnesia"
    When I open "/home/amnesia/video.mp4" with Totem
    Then I see "SampleLocalMp4VideoFrame.png" after at most 10 seconds

  Scenario: I cannot watch an MP4 video stored in non-persistent /home/amnesia/.gnupg
    Given a computer
    And I setup a filesystem share containing sample videos
    And I start Tails from DVD with network unplugged and I login
    And I copy the sample videos to "/home/amnesia/.gnupg" as user "amnesia"
    When I try to open "/home/amnesia/.gnupg/video.mp4" with Totem
    Then I see "TotemUnableToOpen.png" after at most 10 seconds

  Scenario: I can watch a WebM video over HTTPS on the command-line
    Given a computer
    And I start Tails from DVD and I login
    When I open "https://webm.html5.org/test.webm" with Totem
    Then I see "SampleRemoteWebMVideoFrame.png" after at most 10 seconds

  Scenario: I can watch a WebM video over HTTPS without using the command-line
    Given a computer
    And I start Tails from DVD and I login
    When I start Totem through the GNOME menu
    When I load the "https://webm.html5.org/test.webm" URL in Totem
    Then I see "SampleRemoteWebMVideoFrame.png" after at most 10 seconds
