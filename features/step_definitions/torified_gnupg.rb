class OpenPGPKeyserverCommunicationError < StandardError
end

def count_gpg_signatures(key)
  output = @vm.execute_successfully("gpg --batch --list-sigs #{key}",
                                    LIVE_USER).stdout
  return output.scan(/^sig/).count
end

def seahorse_wait_helper(img, time = 20)
  begin
    @screen.wait(img, time)
  rescue FindFailed => e
    if @screen.exists('SeahorseKeyserverError.png')
      raise OpenPGPKeyserverCommunicationError
    else
      # Seahorse has been known to segfault during tests
      syslog = @vm.file_content('/var/log/syslog')
      m = /seahorse\[[0-9]+\]: segfault/.match(syslog)
      assert(!m, 'Seahorse aborted with a segmentation fault')
    end
    # Neither keyserver error nor segfault
    raise e
  end
end

Then /^the key "([^"]+)" has (only|more than) (\d+) signatures$/ do |key, qualifier, num|
  next if @skip_steps_while_restoring_background
  count = count_gpg_signatures(key)
  case qualifier
  when 'only'
    assert_equal(count, num.to_i, "Expected #{num} signatures but instead found #{count}")
  when 'more than'
    assert(count > num.to_i, "Expected more than #{num} signatures but found #{count}")
  else
    raise "Unknown operator #{qualifier} passed"
  end
end

When /^the "([^"]+)" OpenPGP key is not in the live user's public keyring$/ do |keyid|
  next if @skip_steps_while_restoring_background
  assert(!@vm.execute("gpg --batch --list-keys '#{keyid}'", LIVE_USER).success?,
         "The '#{keyid}' key is in the live user's public keyring.")
end

When /^I fetch the "([^"]+)" OpenPGP key using the GnuPG CLI( without any signatures)?$/ do |keyid, without|
  next if @skip_steps_while_restoring_background
  if without
    importopts = '--keyserver-options import-clean'
  else
    importopts = ''
  end
  @new_circuit_tries = 0
  until @new_circuit_tries == $config["MAX_NEW_TOR_CIRCUIT_RETRIES"] do
    begin
      @gnupg_recv_key_res = @vm.execute_successfully(
      "gpg --batch #{importopts} --recv-key '#{keyid}'",
      LIVE_USER)
      break
    rescue ExecutionFailedInVM
      force_new_tor_circuit
    end
  end
  assert(@new_circuit_tries < $config["MAX_NEW_TOR_CIRCUIT_RETRIES"], "Fetching keys with the GnuPG CLI did not succeed after retrying #{@new_circuit_tries} times")
end

When /^the GnuPG fetch is successful$/ do
  next if @skip_steps_while_restoring_background
  assert(@gnupg_recv_key_res.success?,
         "gpg keyserver fetch failed:\n#{@gnupg_recv_key_res.stderr}")
end

When /^GnuPG uses the configured keyserver$/ do
  next if @skip_steps_while_restoring_background
  assert(@gnupg_recv_key_res.stderr[CONFIGURED_KEYSERVER_HOSTNAME],
         "GnuPG's stderr did not mention keyserver #{CONFIGURED_KEYSERVER_HOSTNAME}")
end

When /^the "([^"]+)" key is in the live user's public keyring after at most (\d+) seconds$/ do |keyid, delay|
  next if @skip_steps_while_restoring_background
  try_for(delay.to_f, :msg => "The '#{keyid}' key is not in the live user's public keyring") {
    @vm.execute("gpg --batch --list-keys '#{keyid}'", LIVE_USER).success?
  }
end

When /^I start Seahorse( via the Tails OpenPGP Applet)?$/ do |withgpgapplet|
  next if @skip_steps_while_restoring_background
  if withgpgapplet
    seahorse_menu_click_helper('GpgAppletIconNormal.png', 'GpgAppletManageKeys.png')
  else
    step 'I start "Seahorse" via the GNOME "System"/"Preferences" applications menu'
  end
end

Then /^Seahorse has opened$/ do
  next if @skip_steps_while_restoring_background
  seahorse_wait_helper('SeahorseWindow.png')
end

Then /^I enable key synchronization in Seahorse$/ do
  next if @skip_steps_while_restoring_background
  step 'process "seahorse" is running'
  @screen.wait_and_click("SeahorseWindow.png", 10)
  seahorse_menu_click_helper('SeahorseEdit.png', 'SeahorseEditPreferences.png', 'seahorse')
  seahorse_wait_helper('SeahorsePreferences.png')
  @screen.type("p", Sikuli::KeyModifier.ALT) # Option: "Publish keys to...".
  @screen.type(Sikuli::Key.DOWN) # select HKP server
  @screen.type("c", Sikuli::KeyModifier.ALT) # Button: "Close"
end

Then /^I synchronize keys in Seahorse$/ do
  next if @skip_steps_while_restoring_background
  @new_circuit_tries = 0
  until @new_circuit_tries == $config["MAX_NEW_TOR_CIRCUIT_RETRIES"] do
    begin
      step 'process "seahorse" is running'
      @screen.wait_and_click("SeahorseWindow.png", 10)
      seahorse_menu_click_helper('SeahorseRemoteMenu.png', 'SeahorseRemoteMenuSync.png', 'seahorse')
      seahorse_wait_helper('SeahorseSyncKeys.png')
      @screen.type("s", Sikuli::KeyModifier.ALT) # Button: Sync
      seahorse_wait_helper('SeahorseSynchronizing.png')
      seahorse_wait_helper('SeahorseWindow.png', 5*60)
      break
    rescue OpenPGPKeyserverCommunicationError
      force_new_tor_circuit
      @screen.wait_and_click('GnomeCloseButton.png', 20)
      if @screen.exists('SeahorseSynchronizing.png')
        # Seahorse is likely to segfault if we end up here.
        @screen.click('SeahorseSynchronizing.png')
        @screen.type(Sikuli::Key.ESC)
      end
      seahorse_wait_helper('SeahorseWindow.png')
    end
  end
  assert(@new_circuit_tries < $config["MAX_NEW_TOR_CIRCUIT_RETRIES"], "Syncing keys in Seahorse did not succeed after retrying #{@new_circuit_tries} times")
end

When /^I fetch the "([^"]+)" OpenPGP key using Seahorse( via the Tails OpenPGP Applet)?$/ do |keyid, withgpgapplet|
  next if @skip_steps_while_restoring_background
  if withgpgapplet
    step "I start Seahorse via the Tails OpenPGP Applet"
  else
    step "I start Seahorse"
  end
  step "Seahorse has opened"
  @new_circuit_tries = 0
  until @new_circuit_tries == $config["MAX_NEW_TOR_CIRCUIT_RETRIES"] do
    begin
      @screen.wait_and_click("SeahorseWindow.png", 10)
      seahorse_menu_click_helper('SeahorseRemoteMenu.png', 'SeahorseRemoteMenuFind.png', 'seahorse')
      seahorse_wait_helper('SeahorseFindKeysWindow.png', 10)
      # Seahorse doesn't seem to support searching for fingerprints
      @screen.type(keyid + Sikuli::Key.ENTER)
      begin
        seahorse_wait_helper('SeahorseFoundKeyResult.png', 5*60)
      rescue FindFailed
        # We may end up here if Seahorse appears to be "frozen".
        # Sometimes--but not always--if we click another window
        # the main Seahorse window will unfreeze, allowing us
        # to continue normally.
        @screen.click("SeahorseSearch.png")
      end
      @screen.click("SeahorseKeyResultWindow.png")
      @screen.click("SeahorseFoundKeyResult.png")
      @screen.click("SeahorseImport.png")
      break
    rescue OpenPGPKeyserverCommunicationError
      force_new_tor_circuit
      @screen.wait_and_click('GnomeCloseButton.png', 20)
      @screen.type(Sikuli::Key.ESC)
      @screen.type("w", Sikuli::KeyModifier.CTRL)
    end
  end
  assert(@new_circuit_tries < $config["MAX_NEW_TOR_CIRCUIT_RETRIES"], "Fetching keys in Seahorse did not succeed after retrying #{@new_circuit_tries} times")
end

Then /^Seahorse is configured to use the correct keyserver$/ do
  next if @skip_steps_while_restoring_background
  @gnome_keyservers = YAML.load(@vm.execute_successfully('gsettings get org.gnome.crypto.pgp keyservers',
                                                         LIVE_USER).stdout)
  assert_equal(1, @gnome_keyservers.count, 'Seahorse should only have one keyserver configured.')
  # Seahorse doesn't support hkps so that part of the domain is stripped out.
  # We also insert hkp:// to the beginning of the domain.
  assert_equal(CONFIGURED_KEYSERVER_HOSTNAME.gsub('hkps.', 'hkp://'), @gnome_keyservers[0])
end
