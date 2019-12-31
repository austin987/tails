@product
Feature: Using Totem
  As a Tails user
  I want to watch local and remote videos in Totem
  And AppArmor should prevent Totem from doing dangerous things
  And all Internet traffic should flow only through Tor

  Background:
    Given I create sample videos

  Scenario: Watching a MP4 video stored on the non-persistent filesystem
    Given I have started Tails from DVD without network and logged in
    And I plug and mount a USB drive containing sample videos
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
    Given I close Totem
    And I copy "/home/amnesia/video.mp4" to "/home/amnesia/.purple/otr.private_key" as user "amnesia"
    And I restart monitoring the AppArmor log of "/usr/bin/totem"
    When I try to open "/home/amnesia/.purple/otr.private_key" with Totem
    Then I see "TotemUnableToOpen.png" after at most 10 seconds
    And AppArmor has denied "/usr/bin/totem" from opening "/home/amnesia/.purple/otr.private_key"

  @check_tor_leaks
  Scenario: Watching a WebM video over HTTPS
    Given I have started Tails from DVD and logged in and the network is connected
    Then I can watch a WebM video over HTTPs

  Scenario: Watching MP4 videos stored on the persistent volume should work as expected given our AppArmor confinement
    Given I have started Tails without network from a USB drive with a persistent partition enabled and logged in
    And I plug and mount a USB drive containing sample videos
    And I copy the sample videos to "/home/amnesia/Persistent" as user "amnesia"
    When I open "/home/amnesia/Persistent/video.mp4" with Totem
    Then I see "SampleLocalMp4VideoFrame.png" after at most 40 seconds
    Given I close Totem
    And I start monitoring the AppArmor log of "/usr/bin/totem"
    And I copy the sample videos to "/home/amnesia/.gnupg" as user "amnesia"
    When I try to open "/home/amnesia/.gnupg/video.mp4" with Totem
    Then I see "TotemUnableToOpen.png" after at most 10 seconds
    And AppArmor has denied "/usr/bin/totem" from opening "/home/amnesia/.gnupg/video.mp4"
