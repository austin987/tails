Then /^Icedove has started$/ do
  step 'process "icedove" is running within 30 seconds'
  @screen.wait('IcedoveMainWindow.png', 60)
end

When /^I have not configured an email account$/ do
  icedove_prefs = $vm.file_content("/home/#{LIVE_USER}/.icedove/profile.default/prefs.js").chomp
  assert(!icedove_prefs.include?('mail.accountmanager.accounts'))
end

Then /^I am prompted to setup an email account$/ do
  $vm.focus_window('Mail Account Setup')
  @screen.wait('IcedoveMailAccountSetup.png', 30)
end

Then /^IMAP is the default protocol$/ do
  $vm.focus_window('Mail Account Setup')
  @screen.wait('IcedoveProtocolIMAP.png', 10)
end

Then /^I cancel setting up an email account$/ do
  $vm.focus_window('Mail Account Setup')
  @screen.type(Sikuli::Key.ESC)
  @screen.waitVanish('IcedoveMailAccountSetup.png', 10)
end

Then /^I open Icedove's Add-ons Manager$/ do
  $vm.focus_window('Icedove')
  @screen.wait_and_click('MozillaMenuButton.png', 10)
  @screen.wait_and_click('IcedoveToolsMenuAddOns.png', 10)
  @screen.wait('MozillaAddonsManagerExtensions.png', 30)
end

Then /^I click the extensions tab$/ do
  @screen.wait_and_click('MozillaAddonsManagerExtensions.png', 10)
end

Then /^I see that Adblock is not installed in Icedove$/ do
  if @screen.exists('MozillaExtensionsAdblockPlus.png')
    raise 'Adblock should not be enabled within Icedove'
  end
end

When /^I go into Enigmail's preferences$/ do
  $vm.focus_window('Icedove')
  @screen.type("a", Sikuli::KeyModifier.ALT)
  @screen.wait_and_click('IcedoveEnigmailPreferences.png', 10)
  @screen.wait('IcedoveEnigmailPreferencesWindow.png', 10)
  @screen.click('IcedoveEnigmailExpertSettingsButton.png')
  @screen.wait('IcedoveEnigmailKeyserverTab.png', 10)
end

When /^I click Enigmail's keyserver tab$/ do
  @screen.wait_and_click('IcedoveEnigmailKeyserverTab.png', 10)
end

Then /^I see that Enigmail is configured to use the correct keyserver$/ do
  @screen.wait('IcedoveEnigmailKeyserver.png', 10)
end

Then /^I click Enigmail's advanced tab$/ do
  @screen.wait_and_click('IcedoveEnigmailAdvancedTab.png', 10)
end

Then /^I see that Enigmail is configured to use the correct SOCKS proxy$/ do
  @screen.click('IcedoveEnigmailAdvancedParameters.png')
  @screen.type(Sikuli::Key.END)
  @screen.wait('IcedoveEnigmailProxy.png', 10)
end

Then /^I see that Torbirdy is configured to use Tor$/ do
  @screen.wait('IcedoveTorbirdyEnabled.png', 10)
end

When /^I open Torbirdy's preferences$/ do
  step "I open Icedove's Add-ons Manager"
  step 'I click the extensions tab'
  @screen.wait_and_click('MozillaExtensionsTorbirdy.png', 10)
  @screen.type(Sikuli::Key.TAB)   # Select 'More' link
  @screen.type(Sikuli::Key.TAB)   # Select 'Preferences' button
  @screen.type(Sikuli::Key.SPACE) # Press 'Preferences' button
  @screen.wait('GnomeQuestionDialogIcon.png', 10)
  @screen.type(Sikuli::Key.ENTER)
end
