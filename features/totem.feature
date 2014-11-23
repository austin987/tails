@product
Feature: Using Totem
  As a Tails user
  I want to watch local and remote videos in Totem
  And AppArmor should prevent Totem from doing dangerous things
  And all Internet traffic should flow only through Tor

  # We cannot use Background to save a snapshot of an already booted
  # Tails here, due to bugs with filesystem shares vs. snapshots, as
  # explained in checks.feature.

  Background:
    Given I create sample videos

  Scenario: Watching a MP4 video stored on the non-persistent filesystem
    Given a computer
    And I setup a filesystem share containing sample videos
    And I start Tails from DVD with network unplugged and I login
    And I copy the sample videos to "/home/amnesia" as user "amnesia"
    When I open "/home/amnesia/video.mp4" with Totem
    Then I see "SampleLocalMp4VideoFrame.png" after at most 10 seconds
    Given I close Totem
    And I copy the sample videos to "/home/amnesia/.gnupg" as user "amnesia"
    When I try to open "/home/amnesia/.gnupg/video.mp4" with Totem
    Then I see "TotemUnableToOpen.png" after at most 10 seconds

  Scenario: Watching a WebM video over HTTPS, with and without the command-line
    Given a computer
    And I capture all network traffic
    And I start Tails from DVD and I login
    When I open "https://webm.html5.org/test.webm" with Totem
    Then I see "SampleRemoteWebMVideoFrame.png" after at most 10 seconds
    When I close Totem
    And I start Totem through the GNOME menu
    When I load the "https://webm.html5.org/test.webm" URL in Totem
    Then I see "SampleRemoteWebMVideoFrame.png" after at most 10 seconds
    And all Internet traffic has only flowed through Tor

  @keep_volumes
  Scenario: Installing Tails on a USB drive, creating a persistent partition, copying video files to it
    Given the USB drive "current" contains Tails with persistence configured and password "asdf"
    And a computer
    And I setup a filesystem share containing sample videos
    And I start Tails from USB drive "current" with network unplugged and I login with persistence password "asdf"
    And I copy the sample videos to "/home/amnesia/Persistent" as user "amnesia"
    And I copy the sample videos to "/home/amnesia/.gnupg" as user "amnesia"
    And I shutdown Tails and wait for the computer to power off

  @keep_volumes
  Scenario: Watching a MP4 video stored on the persistent volume
    Given a computer
    And I start Tails from USB drive "current" with network unplugged and I login with persistence password "asdf"
    And the file "/home/amnesia/Persistent/video.mp4" exists
    When I open "/home/amnesia/Persistent/video.mp4" with Totem
    Then I see "SampleLocalMp4VideoFrame.png" after at most 10 seconds
    Given I close Totem
    And the file "/home/amnesia/.gnupg/video.mp4" exists
    When I try to open "/home/amnesia/.gnupg/video.mp4" with Totem
    Then I see "TotemUnableToOpen.png" after at most 10 seconds
