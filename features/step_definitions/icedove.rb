def icedove_app
  Dogtail::Application.new('Icedove')
end

def icedove_main
  icedove_app.child('Home - Icedove Mail/News', roleName: 'frame')
end

def icedove_wizard
  icedove_app.child('Mail Account Setup', roleName: 'frame')
end

Then /^Icedove has started$/ do
  icedove_main.wait(60)
end

When /^I have not configured an email account$/ do
  icedove_prefs = $vm.file_content("/home/#{LIVE_USER}/.icedove/profile.default/prefs.js").chomp
  assert(!icedove_prefs.include?('mail.accountmanager.accounts'))
end

Then /^I am prompted to setup an email account$/ do
  icedove_wizard.wait(30)
end

Then /^I cancel setting up an email account$/ do
  icedove_wizard.button('Cancel').click
end

Then /^I open Icedove's Add-ons Manager$/ do
  icedove_main.button('AppMenu').click
  icedove_main.child('Add-ons', roleName: 'menu item').click
  @icedove_addons = icedove_app.child(
    'Add-ons Manager - Icedove Mail/News', roleName: 'frame'
  )
  @icedove_addons.wait
end

Then /^I click the extensions tab$/ do
  @icedove_addons.child('Extensions', roleName: 'list item').click
end

Then /^I see that only the (.+) addons are enabled in Icedove$/ do |addons|
  expected_addons = addons.split(/, | and /)
  actual_addons =
    @icedove_addons.child('amnesia branding', roleName: 'label')
    .parent.parent.children(roleName: 'list item', recursive: false)
    .map { |item| item.name }
  expected_addons.each do |addon|
    result = actual_addons.find { |e| e.start_with?(addon) }
    assert_not_nil(result)
    actual_addons.delete(result)
  end
  assert_equal(0, actual_addons.size)
end

When /^I go into Enigmail's preferences$/ do
  $vm.focus_window('Icedove')
  @screen.type("a", Sikuli::KeyModifier.ALT)
  icedove_main.child('Preferences', roleName: 'menu item').click
  @enigmail_prefs = icedove_app.dialog('Enigmail Preferences')
end

When /^I enable Enigmail's expert settings$/ do
  @enigmail_prefs.button('Display Expert Settings and Menus').click
end

Then /^I click Enigmail's (.+) tab$/ do |tab_name|
  @enigmail_prefs.child(tab_name, roleName: 'page tab').click
end

Then /^I see that Enigmail is configured to use the correct keyserver$/ do
  keyservers = @enigmail_prefs.child(
    'Specify your keyserver(s):', roleName: 'entry'
  ).text
  assert_equal('hkps://hkps.pool.sks-keyservers.net', keyservers)
end

Then /^I see that Enigmail is configured to use the correct SOCKS proxy$/ do
  gnupg_parameters = @enigmail_prefs.child(
    'Additional parameters for GnuPG', roleName: 'entry'
  ).text
  assert_not_nil(
    gnupg_parameters['--keyserver-options http-proxy=socks5h://127.0.0.1:9050']
  )
end

Then /^I see that Torbirdy is configured to use Tor$/ do
  icedove_main.child(roleName: 'status bar')
    .child('TorBirdy Enabled:    Tor', roleName: 'label').wait
end
