def configured_pidgin_accounts
  accounts = []
  xml = REXML::Document.new(@vm.file_content('$HOME/.purple/accounts.xml',
                                             $live_user))
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
  @screen.wait_and_click("GnomeApplicationsMenu.png", 10)
  @screen.wait_and_click("GnomeApplicationsInternet.png", 10)
  @screen.wait_and_click("GnomeApplicationsPidgin.png", 20)
end

When /^I open Pidgin's account manager window$/ do
  next if @skip_steps_while_restoring_background
  @screen.type("a", Sikuli::KeyModifier.CTRL) # shortcut for "manage accounts"
  step "I see Pidgin's account manager window"
end

When /^I see Pidgin's account manager window$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("PidginAccountWindow.png", 20)
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

Then /^Pidgin successfully connects to the "([^"]+)" account$/ do |account|
  next if @skip_steps_while_restoring_background
  expected_channel_entry = chan_image(account, default_chan(account), 'roaster')
  @screen.wait(expected_channel_entry, 60)
end

Then /^I can join the "([^"]+)" channel on "([^"]+)"$/ do |channel, account|
  next if @skip_steps_while_restoring_background
  @screen.doubleClick(   chan_image(account, channel, 'roaster'))
  @screen.wait_and_click(chan_image(account, channel, 'conversation_tab'), 10)
  @screen.wait(          chan_image(account, channel, 'welcome'), 10)
end
