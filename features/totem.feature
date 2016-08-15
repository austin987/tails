@product
Feature: Using Totem
  As a Tails user
  I want to watch local and remote videos in Totem
  And AppArmor should prevent Totem from doing dangerous things
  And all Internet traffic should flow only through Tor

  Background:
    Given I create sample videos

  Scenario: Watching a MP4 video stored on the non-persistent filesystem
    Given a computer
    And I setup a filesystem share containing sample videos
    And I start Tails from DVD with network unplugged and I login
    And I copy the sample videos to "/home/amnesia" as user "amnesia"
    And the file "/home/amnesia/video.mp4" exists
    Given I start monitoring the AppArmor log of "/usr/bin/totem"
    When I open "/home/amnesia/video.mp4" with Totem
    Then I see "SampleLocalMp4VideoFrame.png" after at most 40 seconds
    And AppArmor has not denied "/usr/bin/totem" from opening "/home/amnesia/video.mp4"
    Given I close Totem
    And I copy the sample videos to "/home/amnesia/.gnupg" as user "amnesia"
    And the file "/home/amnesia/.gnupg/video.mp4" exists
    And I restart monitoring the AppArmor log of "/usr/bin/totem"
    When I try to open "/home/amnesia/.gnupg/video.mp4" with Totem
    Then I see "TotemUnableToOpen.png" after at most 10 seconds
    And AppArmor has denied "/usr/bin/totem" from opening "/home/amnesia/.gnupg/video.mp4"
    Given I close Totem
    And the file "/lib/live/mount/overlay/home/amnesia/.gnupg/video.mp4" exists
    And I restart monitoring the AppArmor log of "/usr/bin/totem"
    When I try to open "/lib/live/mount/overlay/home/amnesia/.gnupg/video.mp4" with Totem
    Then I see "TotemUnableToOpen.png" after at most 10 seconds
    And AppArmor has denied "/usr/bin/totem" from opening "/lib/live/mount/overlay/home/amnesia/.gnupg/video.mp4"
    Given I close Totem
    And the file "/live/overlay/home/amnesia/.gnupg/video.mp4" exists
    And I restart monitoring the AppArmor log of "/usr/bin/totem"
    When I try to open "/live/overlay/home/amnesia/.gnupg/video.mp4" with Totem
    Then I see "TotemUnableToOpen.png" after at most 10 seconds
    # Due to our AppArmor aliases, /live/overlay will be treated
    # as /lib/live/mount/overlay.
    And AppArmor has denied "/usr/bin/totem" from opening "/lib/live/mount/overlay/home/amnesia/.gnupg/video.mp4"

  @check_tor_leaks @fragile
  Scenario: Watching a WebM video over HTTPS
    Given I have started Tails from DVD and logged in and the network is connected
    Then I can watch a WebM video over HTTPs

  #10720: Tails Installer freezes on Jenkins
  @fragile
  Scenario: Watching MP4 videos stored on the persistent volume should work as expected given our AppArmor confinement
    Given I have started Tails without network from a USB drive with a persistent partition and stopped at Tails Greeter's login screen
    # Due to bug #5571 we have to reboot to be able to use
    # filesystem shares.
    And I shutdown Tails and wait for the computer to power off
    And I setup a filesystem share containing sample videos
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    And I copy the sample videos to "/home/amnesia/Persistent" as user "amnesia"
    And I copy the sample videos to "/home/amnesia/.gnupg" as user "amnesia"
    And I shutdown Tails and wait for the computer to power off
    And I start Tails from USB drive "__internal" with network unplugged and I login with persistence enabled
    And the file "/home/amnesia/Persistent/video.mp4" exists
    When I open "/home/amnesia/Persistent/video.mp4" with Totem
    Then I see "SampleLocalMp4VideoFrame.png" after at most 40 seconds
    Given I close Totem
    And the file "/home/amnesia/.gnupg/video.mp4" exists
    And I start monitoring the AppArmor log of "/usr/bin/totem"
    When I try to open "/home/amnesia/.gnupg/video.mp4" with Totem
    Then I see "TotemUnableToOpen.png" after at most 10 seconds
    And AppArmor has denied "/usr/bin/totem" from opening "/home/amnesia/.gnupg/video.mp4"
