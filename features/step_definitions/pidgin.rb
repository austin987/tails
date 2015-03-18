def configured_pidgin_accounts
  accounts = []
  xml = REXML::Document.new(@vm.file_content('$HOME/.purple/accounts.xml',
                                             LIVE_USER))
  xml.elements.each("account/account") do |e|
    account   = e.elements["name"].text
    account_name, network = account.split("@")
    protocol  = e.elements["protocol"].text
    port      = e.elements["settings/setting[@name='port']"].text
    nickname  = e.elements["settings/setting[@name='username']"].text
    real_name = e.elements["settings/setting[@name='realname']"].text
    accounts.push({
                    'name'      => account_name,
                    'network'   => network,
                    'protocol'  => protocol,
                    'port'      => port,
                    'nickname'  => nickname,
                    'real_name' => real_name,
                  })
  end

  return accounts
end

def chan_image (account, channel, image)
  images = {
    'irc.oftc.net' => {
      '#tails' => {
        'roaster'          => 'PidginTailsChannelEntry',
        'conversation_tab' => 'PidginTailsConversationTab',
        'welcome'          => 'PidginTailsChannelWelcome',
      }
    }
  }
  return images[account][channel][image] + ".png"
end

def default_chan (account)
  chans = {
    'irc.oftc.net' => '#tails',
  }
  return chans[account]
end

def pidgin_otr_keys
  return @vm.file_content('$HOME/.purple/otr.private_key', LIVE_USER)
end

Given /^Pidgin has the expected accounts configured with random nicknames$/ do
  next if @skip_steps_while_restoring_background
  expected = [
            ["irc.oftc.net", "prpl-irc", "6697"],
            ["127.0.0.1",    "prpl-irc", "6668"],
          ]
  configured_pidgin_accounts.each() do |account|
    assert(account['nickname'] != "XXX_NICK_XXX", "Nickname was no randomised")
    assert_equal(account['nickname'], account['real_name'],
                 "Nickname and real name are not identical: " +
                 account['nickname'] + " vs. " + account['real_name'])
    assert_equal(account['name'], account['nickname'],
                 "Account name and nickname are not identical: " +
                 account['name'] + " vs. " + account['nickname'])
    candidate = [account['network'], account['protocol'], account['port']]
    assert(expected.include?(candidate), "Unexpected account: #{candidate}")
    expected.delete(candidate)
  end
  assert(expected.empty?, "These Pidgin accounts are not configured: " +
         "#{expected}")
end

When /^I start Pidgin through the GNOME menu$/ do
  next if @skip_steps_while_restoring_background
  step 'I start "Pidgin" via the GNOME "Internet" applications menu'
end

When /^I open Pidgin's account manager window$/ do
  next if @skip_steps_while_restoring_background
  @screen.type("a", Sikuli::KeyModifier.CTRL) # shortcut for "manage accounts"
  step "I see Pidgin's account manager window"
end

When /^I see Pidgin's account manager window$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("PidginAccountWindow.png", 40)
end

When /^I close Pidgin's account manager window$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("PidginAccountManagerCloseButton.png", 10)
end

When /^I activate the "([^"]+)" Pidgin account$/ do |account|
  next if @skip_steps_while_restoring_background
  @screen.click("PidginAccount_#{account}.png")
  @screen.type(Sikuli::Key.LEFT + Sikuli::Key.SPACE)
  # wait for the Pidgin to be connecting, otherwise sometimes the step
  # that closes the account management dialog happens before the account
  # is actually enabled
  @screen.wait("PidginConnecting.png", 5)
end

def focus_pidgin_buddy_list
  @vm.execute_successfully(
    "xdotool search --name 'Buddy List' windowactivate --sync", LIVE_USER
  )
end

Then /^Pidgin successfully connects to the "([^"]+)" account$/ do |account|
  next if @skip_steps_while_restoring_background
  expected_channel_entry = chan_image(account, default_chan(account), 'roaster')
  # Sometimes the OFTC welcome notice window pops up over the buddy list one...
  focus_pidgin_buddy_list
  @screen.wait(expected_channel_entry, 60)
end

Then /^I can join the "([^"]+)" channel on "([^"]+)"$/ do |channel, account|
  next if @skip_steps_while_restoring_background
  @screen.doubleClick(   chan_image(account, channel, 'roaster'))
  @screen.wait_and_click(chan_image(account, channel, 'conversation_tab'), 10)
  @screen.wait(          chan_image(account, channel, 'welcome'), 10)
end

Then /^I take note of the configured Pidgin accounts$/ do
  next if @skip_steps_while_restoring_background
  @persistent_pidgin_accounts = configured_pidgin_accounts
end

Then /^I take note of the OTR key for Pidgin's "([^"]+)" account$/ do |account_name|
  next if @skip_steps_while_restoring_background
  @persistent_pidgin_otr_keys = pidgin_otr_keys
end

Then /^Pidgin has the expected persistent accounts configured$/ do
  next if @skip_steps_while_restoring_background
  current_accounts = configured_pidgin_accounts
  assert(current_accounts <=> @persistent_pidgin_accounts,
         "Currently configured Pidgin accounts do not match the persistent ones:\n" +
         "Current:\n#{current_accounts}\n" +
         "Persistent:\n#{@persistent_pidgin_accounts}"
         )
end

Then /^Pidgin has the expected persistent OTR keys$/ do
  next if @skip_steps_while_restoring_background
  assert_equal(pidgin_otr_keys, @persistent_pidgin_otr_keys)
end

def pidgin_add_certificate_from (cert_file)
  # Here, we need a certificate that is not already in the NSS database
  step "I copy \"/usr/share/ca-certificates/spi-inc.org/spi-cacert-2008.crt\" to \"#{cert_file}\" as user \"amnesia\""

  @screen.wait_and_click('PidginToolsMenu.png', 10)
  @screen.wait_and_click('PidginCertificatesMenuItem.png', 10)
  @screen.wait('PidginCertificateManagerDialog.png', 10)
  @screen.wait_and_click('PidginCertificateAddButton.png', 10)
  begin
    @screen.wait_and_click('GtkFileChooserDesktopButton.png', 10)
  rescue FindFailed
    # The first time we're run, the file chooser opens in the Recent
    # view, so we have to browse a directory before we can use the
    # "Type file name" button. But on subsequent runs, the file
    # chooser is already in the Desktop directory, so we don't need to
    # do anything. Hence, this noop exception handler.
  end
  @screen.wait_and_click('GtkFileTypeFileNameButton.png', 10)
  @screen.type("l", Sikuli::KeyModifier.ALT) # "Location" field
  @screen.type(cert_file + Sikuli::Key.ENTER)
end

Then /^I can add a certificate from the "([^"]+)" directory to Pidgin$/ do |cert_dir|
  next if @skip_steps_while_restoring_background
  pidgin_add_certificate_from("#{cert_dir}/test.crt")
  @screen.wait('PidginCertificateAddHostnameDialog.png', 10)
  @screen.type("XXX test XXX" + Sikuli::Key.ENTER)
  @screen.wait('PidginCertificateTestItem.png', 10)
end

Then /^I cannot add a certificate from the "([^"]+)" directory to Pidgin$/ do |cert_dir|
  next if @skip_steps_while_restoring_background
  pidgin_add_certificate_from("#{cert_dir}/test.crt")
  @screen.wait('PidginCertificateImportFailed.png', 10)
end

When /^I close Pidgin's certificate manager$/ do
  @screen.type(Sikuli::Key.ESC)
  # @screen.wait_and_click('PidginCertificateManagerClose.png', 10)
  @screen.waitVanish('PidginCertificateManagerDialog.png', 10)
end

When /^I close Pidgin's certificate import failure dialog$/ do
  @screen.type(Sikuli::Key.ESC)
  # @screen.wait_and_click('PidginCertificateManagerClose.png', 10)
  @screen.waitVanish('PidginCertificateImportFailed.png', 10)
end

When /^I see the Tails roadmap URL$/ do
  @screen.wait('PidginTailsRoadmapUrl.png', 10)
end

When /^I click on the Tails roadmap URL$/ do
  @screen.click('PidginTailsRoadmapUrl.png')
end
