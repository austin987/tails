@product
Feature: Using VeraCrypt encrypted volumes
  In order to collaborate with non-Tails users
  As a Tails user
  I want to unlock VeraCrypt encrypted volumes

  Background:
    Given I have started Tails from DVD without network and logged in

  @unlock_veracrypt_volumes @usb_drive
  Scenario: Use Unlock VeraCrypt Volumes to unlock a USB drive that has a basic VeraCrypt volume
    Given USB drive "vc-basic" has a basic VeraCrypt volume
    When I plug USB drive "vc-basic"
    And I unlock and mount the VeraCrypt volume on drive "vc-basic" with Unlock VeraCrypt Volumes
    And I open the VeraCrypt volume "vc-basic" in GNOME Files
    Then I see "SecretFileOnVeraCryptVolume.png" after at most 10 seconds
    When I lock the currently opened VeraCrypt volume
    Then I am told the VeraCrypt volume has been unmounted

  @gnome_disks @usb_drive
  Scenario: Use GNOME Disks to unlock a USB drive that has a basic VeraCrypt volume with a keyfile
    Given USB drive "vc-basic-with-keyfile" has a basic VeraCrypt volume with a keyfile
    When I plug USB drive "vc-basic-with-keyfile"
    And I unlock and mount the VeraCrypt volume on drive "vc-basic-with-keyfile" with GNOME Disks
    And I open the VeraCrypt volume "vc-basic-with-keyfile" in GNOME Files
    Then I see "SecretFileOnVeraCryptVolume.png" after at most 10 seconds
    When I lock the currently opened VeraCrypt volume
    Then I am told the VeraCrypt volume has been unmounted

  @unlock_veracrypt_volumes @usb_drive
  Scenario: Use Unlock VeraCrypt Volumes to unlock a USB drive that has a hidden VeraCrypt volume
    Given USB drive "vc-hidden" has a hidden VeraCrypt volume
    When I plug USB drive "vc-hidden"
    And I unlock and mount the VeraCrypt volume on drive "vc-hidden" with Unlock VeraCrypt Volumes
    And I open the VeraCrypt volume "vc-hidden" in GNOME Files
    Then I see "SecretFileOnVeraCryptVolume.png" after at most 10 seconds
    When I lock the currently opened VeraCrypt volume
    Then I am told the VeraCrypt volume has been unmounted

  @gnome_disks @usb_drive
  Scenario: Use GNOME Disks to unlock a USB drive that has a hidden VeraCrypt volume
    Given USB drive "vc-hidden" has a hidden VeraCrypt volume
    When I plug USB drive "vc-hidden"
    And I unlock and mount the VeraCrypt volume on drive "vc-hidden" with GNOME Disks
    And I open the VeraCrypt volume "vc-hidden" in GNOME Files
    Then I see "SecretFileOnVeraCryptVolume.png" after at most 10 seconds
    When I lock the currently opened VeraCrypt volume
    Then I am told the VeraCrypt volume has been unmounted

  @unlock_veracrypt_volumes @file_container
  Scenario: Use Unlock VeraCrypt Volumes to unlock a basic VeraCrypt file container
    Given "vc-basic" is a basic VeraCrypt file container
    When I plug and mount a USB drive containing the "vc-basic" VeraCrypt file container
    And I unlock and mount the "vc-basic" VeraCrypt file container with Unlock VeraCrypt Volumes
    And I open the VeraCrypt volume "vc-basic" in GNOME Files
    Then I see "SecretFileOnVeraCryptVolume.png" after at most 10 seconds
    When I lock the currently opened VeraCrypt file container
    Then I am told the VeraCrypt file container has been unmounted

  # XXX: Add missing file container scenarios.
