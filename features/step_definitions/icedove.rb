Then /^Icedove has started$/ do
  next if @skip_steps_while_restoring_background
  step 'process "icedove" is running within 30 seconds'
  @screen.wait('IcedoveMainWindow.png', 60)
end

When /^I have not configured an email account$/ do
  next if @skip_steps_while_restoring_background
  icedove_prefs = @vm.file_content("/home/#{LIVE_USER}/.icedove/profile.default/prefs.js").chomp
  assert(!icedove_prefs.include?('mail.accountmanager.accounts'))
end

Then /^I am prompted to setup an email account$/ do
  next if @skip_steps_while_restoring_background
  @vm.focus_window('Mail Account Setup')
  @screen.wait('IcedoveMailAccountSetup.png', 30)
end

Then /^IMAP is the default protocol$/ do
  next if @skip_steps_while_restoring_background
  @vm.focus_window('Mail Account Setup')
  @screen.wait('IcedoveProtocolIMAP.png', 10)
end

Then /^I cancel setting up an email account$/ do
  next if @skip_steps_while_restoring_background
  @vm.focus_window('Mail Account Setup')
  @screen.type(Sikuli::Key.ESC)
  @screen.waitVanish('IcedoveMailAccountSetup.png', 10)
end

Then /^I open Icedove's Add-ons Manager$/ do
  next if @skip_steps_while_restoring_background
  @vm.focus_window('Icedove')
  @screen.type("t", Sikuli::KeyModifier.ALT)
  @screen.wait_and_click('IcedoveToolsMenuAddOns.png', 10)
  @screen.wait('MozillaAddonsManagerExtensions.png', 30)
end

Then /^I click the extensions tab$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click('MozillaAddonsManagerExtensions.png', 10)
end

Then /^I see that Adblock is not installed in Icedove$/ do
  next if @skip_steps_while_restoring_background
  if @screen.exists('MozillaExtensionsAdblockPlus.png')
    raise 'Adblock should not be enabled within Icedove'
  end
end

Then /^I enable Icedove's status bar$/ do
  next if @skip_steps_while_restoring_background
  @screen.type("v", Sikuli::KeyModifier.ALT)
  @screen.wait_and_hover('IcedoveMenuViewToolbars.png', 10)
  @screen.wait_and_click('IcedoveMenuViewToolbarsStatusBar.png', 10)
end

Then /^I see that Torbirdy is enabled and configured to use Tor$/ do
  @screen.wait('IcedoveTorbirdyEnabled.png', 10)
end

When /^I go into Enigmail's preferences$/ do
  next if @skip_steps_while_restoring_background
  @vm.focus_window('Icedove')
  @screen.type("a", Sikuli::KeyModifier.ALT)
  @screen.wait_and_click('IcedoveEnigmailPreferences.png', 10)
  @screen.wait('IcedoveEnigmailPreferencesWindow.png', 10)
  @screen.click('IcedoveEnigmailExpertSettingsButton.png')
  @screen.wait('IcedoveEnigmailKeyserverTab.png', 10)
end

When /^I click Enigmail's keyserver tab$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click('IcedoveEnigmailKeyserverTab.png', 10)
end

Then /^I see that Enigmail is configured to use the correct keyserver$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('IcedoveEnigmailKeyserver.png', 10)
end

Then /^I click Enigmail's advanced tab$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click('IcedoveEnigmailAdvancedTab.png', 10)
end

Then /^I see that Enigmail is configured to use the correct SOCKS proxy$/ do
  next if @skip_steps_while_restoring_background
  @screen.click('IcedoveEnigmailAdvancedParameters.png')
  @screen.type(Sikuli::Key.END)
  @screen.wait('IcedoveEnigmailProxy.png', 10)
end

When /^I open Torbirdy's preferences$/ do
  next if @skip_steps_while_restoring_background
  step "I open Icedove's Add-ons Manager"
  step 'I click the extensions tab'
  @screen.wait_and_click('MozillaExtensionsTorbirdy.png', 10)
  @screen.type(Sikuli::Key.TAB)   # Select 'More' link
  @screen.type(Sikuli::Key.TAB)   # Select 'Preferences' button
  @screen.type(Sikuli::Key.SPACE) # Press 'Preferences' button
  @screen.wait('GnomeQuestionDialogIcon.png', 10)
  @screen.type(Sikuli::Key.ENTER)
end

When /^I test Torbirdy's proxy settings$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('IcedoveTorbirdyPreferencesWindow.png', 10)
  @screen.click('IcedoveTorbirdyTestProxySettingsButton.png')
  @screen.wait('IcedoveTorbirdyCongratulationsTab.png', 180)
end

Then /^Torbirdy's proxy test is successful$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('IcedoveTorbirdyCongratulationsTab.png', 180)
end
