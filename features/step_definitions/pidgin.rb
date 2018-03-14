# Extracts the secrets for the XMMP account `account_name`.
def xmpp_account(account_name, required_options = [])
  begin
    account = $config["Pidgin"]["Accounts"]["XMPP"][account_name]
    check_keys = ["username", "domain", "password"] + required_options
    for key in check_keys do
      assert(account.has_key?(key))
      assert_not_nil(account[key])
      assert(!account[key].empty?)
    end
  rescue NoMethodError, Test::Unit::AssertionFailedError
    raise(
<<EOF
Your Pidgin:Accounts:XMPP:#{account} is incorrect or missing from your local configuration file (#{LOCAL_CONFIG_FILE}). See wiki/src/contribute/release_process/test/usage.mdwn for the format.
EOF
)
  end
  return account
end

def wait_and_focus(img, time = 10, window)
  begin
    @screen.wait(img, time)
  rescue FindFailed
    $vm.focus_window(window)
    @screen.wait(img, time)
  end
end

def focus_pidgin_irc_conversation_window(account)
  account = account.sub(/^irc\./, '')
  try_for(20) do
    $vm.focus_window(".*#{Regexp.escape(account)}$")
  end
end

# This method should always fail (except with the option
# `return_shellcommand: true`) since we block Pidgin's D-Bus interface
# (#14612) ...
def pidgin_dbus_call(method, *args, **opts)
  opts[:user] = LIVE_USER
  dbus_send(
    'im.pidgin.purple.PurpleService',
    '/im/pidgin/purple/PurpleObject',
    "im.pidgin.purple.PurpleInterface.#{method}",
    *args, **opts
  )
end

# ... unless we re-enable it!
def pidgin_force_allowed_dbus_call(method, *args, **opts)
  opts[:user] = LIVE_USER
  policy_file = '/etc/dbus-1/session.d/im.pidgin.purple.PurpleService.conf'
  $vm.execute_successfully("mv #{policy_file} #{policy_file}.disabled")
  # From dbus-daemon(1): "Policy changes should take effect with SIGHUP"
  # Note that HUP is asynchronous, so there is no guarantee whatsoever
  # that the HUP will take effect before we do the dbus call. In
  # practice, however, the delays imposed by using the remote shell is
  # (in general) much larger than the processing time needed for
  # handling signals, so they are in effect synchronous in our
  # context.
  $vm.execute_successfully("pkill -HUP -u #{opts[:user]} 'dbus-daemon'")
  pidgin_dbus_call(method, *args, **opts)
ensure
  $vm.execute_successfully("mv #{policy_file}.disabled #{policy_file}")
  $vm.execute_successfully("pkill -HUP -u #{opts[:user]} 'dbus-daemon'")
end

def pidgin_account_connected?(account, prpl_protocol)
  account_id = pidgin_force_allowed_dbus_call(
    'PurpleAccountsFind', account, prpl_protocol
  )
  pidgin_force_allowed_dbus_call('PurpleAccountIsConnected', account_id) == 1
end

When /^I create my XMPP account$/ do
  account = xmpp_account("Tails_account")
  @screen.click("PidginAccountManagerAddButton.png")
  @screen.wait("PidginAddAccountWindow.png", 20)
  @screen.click_mid_right_edge("PidginAddAccountProtocolLabel.png")
  @screen.click("PidginAddAccountProtocolXMPP.png")
  # We first wait for some field that is shown for XMPP but not the
  # default (IRC) since we otherwise may decide where we click before
  # the GUI has updated after switching protocol.
  @screen.wait("PidginAddAccountXMPPDomain.png", 5)
  @screen.click_mid_right_edge("PidginAddAccountXMPPUsername.png")
  @screen.type(account["username"])
  @screen.click_mid_right_edge("PidginAddAccountXMPPDomain.png")
  @screen.type(account["domain"])
  @screen.click_mid_right_edge("PidginAddAccountXMPPPassword.png")
  @screen.type(account["password"])
  @screen.click("PidginAddAccountXMPPRememberPassword.png")
  if account["connect_server"]
    @screen.click("PidginAddAccountXMPPAdvancedTab.png")
    @screen.click_mid_right_edge("PidginAddAccountXMPPConnectServer.png")
    @screen.type(account["connect_server"])
  end
  @screen.click("PidginAddAccountXMPPAddButton.png")
end

Then /^Pidgin automatically enables my XMPP account$/ do
  account = xmpp_account("Tails_account")
  jid = account["username"] + '@' + account["domain"]
  try_for(3*60) do
    pidgin_account_connected?(jid, 'prpl-jabber')
  end
  $vm.focus_window('Buddy List')
  @screen.wait("PidginAvailableStatus.png", 60*3)
end

Given /^my XMPP friend goes online( and joins the multi-user chat)?$/ do |join_chat|
  account = xmpp_account("Friend_account", ["otr_key"])
  bot_opts = account.select { |k, v| ["connect_server"].include?(k) }
  if join_chat
    bot_opts["auto_join"] = [@chat_room_jid]
  end
  @friend_name = account["username"]
  @chatbot = ChatBot.new(account["username"] + "@" + account["domain"],
                         account["password"], account["otr_key"], bot_opts)
  @chatbot.start
  add_after_scenario_hook { @chatbot.stop }
  $vm.focus_window('Buddy List')
  @screen.wait("PidginFriendOnline.png", 60)
end

When /^I start a conversation with my friend$/ do
  $vm.focus_window('Buddy List')
  # Clicking the middle, bottom of this image should query our
  # friend, given it's the only subscribed user that's online, which
  # we assume.
  r = @screen.find("PidginFriendOnline.png")
  bottom_left = r.getBottomLeft()
  x = bottom_left.getX + r.getW/2
  y = bottom_left.getY
  @screen.doubleClick_point(x, y)
  # Since Pidgin sets the window name to the contact, we have no good
  # way to identify the conversation window. Let's just look for the
  # expected menu bar.
  @screen.wait("PidginConversationWindowMenuBar.png", 10)
end

And /^I say (.*) to my friend( in the multi-user chat)?$/ do |msg, multi_chat|
  msg = "ping" if msg == "something"
  msg = msg + Sikuli::Key.ENTER
  if multi_chat
    $vm.focus_window(@chat_room_jid.split("@").first)
    msg = @friend_name + ": " + msg
  else
    $vm.focus_window(@friend_name)
  end
  @screen.type(msg)
end

Then /^I receive a response from my friend( in the multi-user chat)?$/ do |multi_chat|
  if multi_chat
    $vm.focus_window(@chat_room_jid.split("@").first)
  else
    $vm.focus_window(@friend_name)
  end
  try_for(60) do
    if @screen.exists('PidginServerMessage.png')
      @screen.click('PidginDialogCloseButton.png')
    end
    @screen.find('PidginFriendExpectedAnswer.png')
  end
end

When /^I start an OTR session with my friend$/ do
  $vm.focus_window(@friend_name)
  @screen.click("PidginConversationOTRMenu.png")
  @screen.hide_cursor
  @screen.click("PidginOTRMenuStartSession.png")
end

Then /^Pidgin automatically generates an OTR key$/ do
  @screen.wait("PidginOTRKeyGenPrompt.png", 30)
  @screen.wait_and_click("PidginOTRKeyGenPromptDoneButton.png", 30)
end

Then /^an OTR session was successfully started with my friend$/ do
  $vm.focus_window(@friend_name)
  @screen.wait("PidginConversationOTRUnverifiedSessionStarted.png", 10)
end

# The reason the chat must be empty is to guarantee that we don't mix
# up messages/events from other users with the ones we expect from the
# bot.
When /^I join some empty multi-user chat$/ do
  $vm.focus_window('Buddy List')
  @screen.click("PidginBuddiesMenu.png")
  @screen.wait_and_click("PidginBuddiesMenuJoinChat.png", 10)
  @screen.wait_and_click("PidginJoinChatWindow.png", 10)
  @screen.click_mid_right_edge("PidginJoinChatRoomLabel.png")
  account = xmpp_account("Tails_account")
  if account.has_key?("chat_room") && \
     !account["chat_room"].nil? && \
     !account["chat_room"].empty?
    chat_room = account["chat_room"]
  else
    chat_room = random_alnum_string(10, 15)
  end
  @screen.type(chat_room)

  # We will need the conference server later, when starting the bot.
  @screen.click_mid_right_edge("PidginJoinChatServerLabel.png")
  @screen.type("a", Sikuli::KeyModifier.CTRL)
  @screen.type("c", Sikuli::KeyModifier.CTRL)
  conference_server =
    $vm.execute_successfully("xclip -o", :user => LIVE_USER).stdout.chomp
  @chat_room_jid = chat_room + "@" + conference_server

  @screen.click("PidginJoinChatButton.png")
  # The following will both make sure that the we joined the chat, and
  # that it is empty. We'll also deal with the *potential* "Create New
  # Room" prompt that Pidgin shows for some server configurations.
  images = ["PidginCreateNewRoomPrompt.png",
            "PidginChat1UserInRoom.png"]
  image_found, _ = @screen.waitAny(images, 30)
  if image_found == "PidginCreateNewRoomPrompt.png"
    @screen.click("PidginCreateNewRoomAcceptDefaultsButton.png")
  end
  $vm.focus_window(@chat_room_jid)
  @screen.wait("PidginChat1UserInRoom.png", 10)
end

# Since some servers save the scrollback, and sends it when joining,
# it's safer to clear it so we do not get false positives from old
# messages when looking for a particular response, or similar.
When /^I clear the multi-user chat's scrollback$/ do
  $vm.focus_window(@chat_room_jid)
  @screen.click("PidginConversationMenu.png")
  @screen.wait_and_click("PidginConversationMenuClearScrollback.png", 10)
end

Then /^I can see that my friend joined the multi-user chat$/ do
  $vm.focus_window(@chat_room_jid)
  @screen.wait("PidginChat2UsersInRoom.png", 60)
end

def configured_pidgin_accounts
  accounts = Hash.new
  xml = REXML::Document.new(
    $vm.file_content("/home/#{LIVE_USER}/.purple/accounts.xml")
  )
  xml.elements.each("account/account") do |e|
    account   = e.elements["name"].text
    account_name, network = account.split("@")
    protocol  = e.elements["protocol"].text
    port      = e.elements["settings/setting[@name='port']"].text
    username_element  = e.elements["settings/setting[@name='username']"]
    realname_elemenet = e.elements["settings/setting[@name='realname']"]
    if username_element
      nickname  = username_element.text
    else
      nickname  = nil
    end
    if realname_elemenet
      real_name = realname_elemenet.text
    else
      real_name = nil
    end
    accounts[network] = {
      'name'      => account_name,
      'network'   => network,
      'protocol'  => protocol,
      'port'      => port,
      'nickname'  => nickname,
      'real_name' => real_name,
    }
  end

  return accounts
end

def chan_image (account, channel, image)
  images = {
    'conference.riseup.net' => {
      'tails' => {
        'conversation_tab' => 'PidginTailsConversationTab',
        'welcome'          => 'PidginTailsChannelWelcome',
      }
    },
  }
  return images[account][channel][image] + ".png"
end

def default_chan (account)
  chans = {
    'conference.riseup.net' => 'tails',
  }
  return chans[account]
end

def pidgin_otr_keys
  return $vm.file_content("/home/#{LIVE_USER}/.purple/otr.private_key")
end

Given /^Pidgin has the expected accounts configured with random nicknames$/ do
  expected = [
            ["irc.oftc.net", "prpl-irc", "6697"],
            ["127.0.0.1",    "prpl-irc", "6668"],
          ]
  configured_pidgin_accounts.values.each() do |account|
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

When /^I open Pidgin's account manager window$/ do
  @screen.wait_and_click('PidginMenuAccounts.png', 20)
  @screen.wait_and_click('PidginMenuManageAccounts.png', 20)
  step "I see Pidgin's account manager window"
end

When /^I see Pidgin's account manager window$/ do
  @screen.wait("PidginAccountWindow.png", 40)
end

When /^I close Pidgin's account manager window$/ do
  @screen.wait_and_click("PidginDialogCloseButton.png", 10)
end

When /^I close Pidgin$/ do
  $vm.focus_window('Buddy List')
  @screen.type("q", Sikuli::KeyModifier.CTRL)
  @screen.waitVanish('PidginAvailableStatus.png', 10)
end

When /^I (de)?activate the "([^"]+)" Pidgin account$/ do |deactivate, account|
  @screen.click("PidginAccount_#{account}.png")
  @screen.type(Sikuli::Key.LEFT + Sikuli::Key.SPACE)
  if deactivate
    @screen.waitVanish('PidginAccountEnabledCheckbox.png', 5)
  else
    # wait for the Pidgin to be connecting, otherwise sometimes the step
    # that closes the account management dialog happens before the account
    # is actually enabled
    @screen.waitAny(['PidginConnecting.png', 'PidginAvailableStatus.png'], 5)
  end
end

def deactivate_and_activate_pidgin_account(account)
  debug_log("Deactivating and reactivating Pidgin account #{account}")
  step "I open Pidgin's account manager window"
  step "I deactivate the \"#{account}\" Pidgin account"
  step "I close Pidgin's account manager window"
  step "I open Pidgin's account manager window"
  step "I activate the \"#{account}\" Pidgin account"
  step "I close Pidgin's account manager window"
end



Then /^Pidgin successfully connects to the "([^"]+)" account$/ do |account|
  expected_channel_entry = chan_image(account, default_chan(account), 'roster')
  reconnect_button = 'PidginReconnect.png'
  recovery_on_failure = Proc.new do
    if @screen.exists('PidginReconnect.png')
      @screen.click('PidginReconnect.png')
    else
      deactivate_and_activate_pidgin_account(account)
    end
  end
  retry_tor(recovery_on_failure) do
    begin
      $vm.focus_window('Buddy List')
    rescue ExecutionFailedInVM
      # Sometimes focusing the window with xdotool will fail with the
      # conversation window right on top of it. We'll try to close the
      # conversation window. At worst, the test will still fail...
      close_pidgin_conversation_window(account)
    end
    on_screen, _ = @screen.waitAny([expected_channel_entry, reconnect_button], 60)
    unless on_screen == expected_channel_entry
      raise "Connecting to account #{account} failed."
    end
  end
end

Then /^the "([^"]*)" account only responds to PING and VERSION CTCP requests$/ do |irc_server|
  ctcp_cmds = [
    "CLIENTINFO", "DATE", "ERRMSG", "FINGER", "PING", "SOURCE", "TIME",
    "USERINFO", "VERSION"
  ]
  expected_ctcp_replies = {
    "PING" => /^\d+$/,
    "VERSION" => /^Purple IRC$/
  }
  spam_target = configured_pidgin_accounts[irc_server]["nickname"]
  ctcp_check = CtcpChecker.new(irc_server, 6667, spam_target, ctcp_cmds,
                               expected_ctcp_replies)
  ctcp_check.verify_ctcp_responses
end

Then /^I can join the( pre-configured)? "([^"]+)" channel on "([^"]+)"$/ do |preconfigured, channel, account|
  if preconfigured
    @screen.doubleClick(chan_image(account, channel, 'roster'))
    focus_pidgin_irc_conversation_window(account)
  else
    $vm.focus_window('Buddy List')
    @screen.wait_and_click("PidginBuddiesMenu.png", 20)
    @screen.wait_and_click("PidginBuddiesMenuJoinChat.png", 10)
    @screen.wait_and_click("PidginJoinChatWindow.png", 10)
    @screen.click_mid_right_edge("PidginJoinChatRoomLabel.png")
    @screen.type(channel)
    @screen.click("PidginJoinChatButton.png")
    @chat_room_jid = channel + "@" + account
    $vm.focus_window(@chat_room_jid)
  end
  @screen.hide_cursor
  try_for(60) do
    begin
      @screen.wait_and_click(chan_image(account, channel, 'conversation_tab'), 5)
    rescue FindFailed => e
      # If the channel tab can't be found it could be because there were
      # multiple connection attempts and the channel tab we want is off the
      # screen. We'll try closing tabs until the one we want can be found.
      @screen.type("w", Sikuli::KeyModifier.CTRL)
      raise e
    end
  end
  @screen.hide_cursor
  @screen.wait(          chan_image(account, channel, 'welcome'), 10)
end

Then /^I take note of the configured Pidgin accounts$/ do
  @persistent_pidgin_accounts = configured_pidgin_accounts
end

Then /^I take note of the OTR key for Pidgin's "([^"]+)" account$/ do |account_name|
  @persistent_pidgin_otr_keys = pidgin_otr_keys
end

Then /^Pidgin has the expected persistent accounts configured$/ do
  current_accounts = configured_pidgin_accounts
  assert(current_accounts <=> @persistent_pidgin_accounts,
         "Currently configured Pidgin accounts do not match the persistent ones:\n" +
         "Current:\n#{current_accounts}\n" +
         "Persistent:\n#{@persistent_pidgin_accounts}"
         )
end

Then /^Pidgin has the expected persistent OTR keys$/ do
  assert_equal(pidgin_otr_keys, @persistent_pidgin_otr_keys)
end

def pidgin_add_certificate_from (cert_file)
  # Here, we need a certificate that is not already in the NSS database
  step "I copy \"/usr/share/ca-certificates/mozilla/CNNIC_ROOT.crt\" to \"#{cert_file}\" as user \"amnesia\""

  $vm.focus_window('Buddy List')
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
  pidgin_add_certificate_from("#{cert_dir}/test.crt")
  wait_and_focus('PidginCertificateAddHostnameDialog.png', 10, 'Certificate Import')
  @screen.type("XXX test XXX" + Sikuli::Key.ENTER)
  wait_and_focus('PidginCertificateTestItem.png', 10, 'Certificate Manager')
end

Then /^I cannot add a certificate from the "([^"]+)" directory to Pidgin$/ do |cert_dir|
  pidgin_add_certificate_from("#{cert_dir}/test.crt")
  wait_and_focus('PidginCertificateImportFailed.png', 10, 'Import Error')
end

When /^I close Pidgin's certificate manager$/ do
  wait_and_focus('PidginCertificateManagerDialog.png', 10, 'Certificate Manager')
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
  try_for(60) do
    if @screen.exists('PidginServerMessage.png')
      @screen.click('PidginDialogCloseButton.png')
    end
    begin
      @screen.find('PidginTailsRoadmapUrl.png')
    rescue FindFailed => e
      @screen.type(Sikuli::Key.PAGE_UP)
      raise e
    end
  end
end

When /^I click on the Tails roadmap URL$/ do
  @screen.click('PidginTailsRoadmapUrl.png')
  try_for(60) { @torbrowser = Dogtail::Application.new('Firefox') }
end

Then /^Pidgin's D-Bus interface is not available$/ do
  # Pidgin must be running to expose the interface
  assert($vm.has_process?('pidgin'))
  # Let's first ensure it would work if not explicitly blocked.
  # Note: that the method we pick here doesn't really matter
  # (`PurpleAccountsGetAll` felt like a convenient choice since it
  # doesn't require any arguments).
  assert_equal(
    Array, pidgin_force_allowed_dbus_call('PurpleAccountsGetAll').class
  )
  # Finally, let's make sure it is blocked
  c = pidgin_dbus_call('PurpleAccountsGetAll', return_shellcommand: true)
  assert(c.failure?)
  assert_not_nil(c.stderr['Rejected send message'])
end
