def count_gpg_signatures(key)
  output = @vm.execute_successfully("gpg --batch --list-sigs #{key}",
                                    LIVE_USER).stdout
  return output.scan(/^sig/).count
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
  @gnupg_recv_key_res = @vm.execute_successfully(
    "gpg --batch #{importopts} --recv-key '#{keyid}'",
    LIVE_USER)
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
    @screen.wait_and_click("GpgAppletIconNormal.png", 10)
    @screen.wait_and_click("GpgAppletManageKeys.png", 10)
  else
    step 'I start "Seahorse" via the GNOME "System"/"Preferences" applications menu'
  end
end

Then /^Seahorse has opened$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("SeahorseWindow.png", 10)
end

Then /^I enable key synchronization in Seahorse$/ do
  next if @skip_steps_while_restoring_background
  step 'process "seahorse" is running'
  @screen.wait_and_click("SeahorseWindow.png", 10)
  @screen.type("e", Sikuli::KeyModifier.ALT) # Menu: "Edit" ->
  @screen.type("n") # Menu: "Preferences " ->
  @screen.wait("SeahorsePreferences.png", 10)
  @screen.type("p", Sikuli::KeyModifier.ALT) # Option: "Publish keys to...".
  @screen.type(Sikuli::Key.DOWN) # select HKP server
  @screen.type("c", Sikuli::KeyModifier.ALT) # Button: "Close"
end

Then /^I synchronize keys in Seahorse$/ do
  next if @skip_steps_while_restoring_background
  step "process \"seahorse\" is running"
  @screen.wait_and_click("SeahorseWindow.png", 10)
  @screen.wait("SeahorseWindow.png", 10)
  @screen.type("r", Sikuli::KeyModifier.ALT) # Menu: "Remote" ->
  @screen.type("s")                  # "Sync...".
  @screen.wait("SeahorseSyncKeys.png", 10)
  @screen.type("s", Sikuli::KeyModifier.ALT) # Button: Sync
  @screen.wait("SeahorseSynchronizing.png", 20)
  @screen.wait("SeahorseWindow.png", 120)
end

When /^I fetch the "([^"]+)" OpenPGP key using Seahorse( via the Tails OpenPGP Applet)?$/ do |keyid, withgpgapplet|
  next if @skip_steps_while_restoring_background
  if withgpgapplet
    step "I start Seahorse via the Tails OpenPGP Applet"
  else
    step "I start Seahorse"
  end
  step "Seahorse has opened"
  @screen.wait_and_click("SeahorseWindow.png", 10)
  @screen.type("r", Sikuli::KeyModifier.ALT) # Menu: "Remote" ->
  @screen.type("f")                  # "Find Remote Keys...".
  @screen.wait("SeahorseFindKeysWindow.png", 10)
  # Seahorse doesn't seem to support searching for fingerprints
  @screen.type(keyid + Sikuli::Key.ENTER)
  @screen.wait("SeahorseFoundKeyResult.png", 5*60)
  @screen.type(Sikuli::Key.DOWN)   # Select first item in result menu
  @screen.type("f", Sikuli::KeyModifier.ALT) # Menu: "File" ->
  @screen.type("i")                  # "Import"
end
