When /^I start Pidgin through the GNOME menu$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("GnomeApplicationsMenu.png", 10)
  @screen.wait_and_click("GnomeApplicationsInternet.png", 10)
  @screen.wait_and_click("GnomeApplicationsPidgin.png", 20)
end

Given /^Pidgin has the expected accounts configured with random nicknames$/ do
  next if @skip_steps_while_restoring_background
  accounts_cfg_file = '$HOME/.purple/accounts.xml'
  cmd = @vm.execute("cat \"#{accounts_cfg_file}\"", $live_user)
  assert(cmd.success?,
         "Could not read '#{accounts_cfg_file}':\n#{cmd.stdout}\n#{cmd.stderr}")
  xml = REXML::Document.new(cmd.stdout)
  expected = [
            ["irc.oftc.net", "prpl-irc", "6697"],
            ["127.0.0.1",    "prpl-irc", "6668"],
          ]
  xml.elements.each("account/account") do |e|
    account = e.elements["name"].text
    account_name, network = account.split("@")
    protocol  = e.elements["protocol"].text
    port      = e.elements["settings/setting[@name='port']"].text
    nickname  = e.elements["settings/setting[@name='username']"].text
    real_name = e.elements["settings/setting[@name='realname']"].text
    STDOUT.puts "#{account_name} #{network} #{nickname} #{real_name}"
    assert(nickname != "XXX_NICK_XXX", "Nickname was no randomised")
    assert_equal(nickname, real_name, "Nickname and real name are not " +
           "identical: '#{nickname}' vs. '#{real_name}'")
    assert_equal(account_name, nickname, "Account name and nickname are not " +
           "identical: '#{account_name}' vs. '#{real_name}'")
    candidate = [network, protocol, port]
    assert(expected.include?(candidate), "Unexpected account: #{candidate}")
    expected.delete(candidate)
  end
  assert(expected.empty?, "These Pidgin accounts are not configured: " +
         "#{expected}")
end

When /^I see Pidgin's account manager window$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("PidginAccountWindow.png", 20)
end

When /^I activate the "([^"]+)" Pidgin account$/ do |account|
  next if @skip_steps_while_restoring_background
  @screen.click("PidginAccount_#{account}.png")
  @screen.type(Sikuli::Key.LEFT + Sikuli::Key.SPACE)
  @screen.type(Sikuli::Key.ESC)
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
