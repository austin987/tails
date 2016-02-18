Given /^I2P is (?:still )?(not )?running$/ do |notrunning|
  if notrunning
    !$vm.execute('systemctl --quiet is-active i2p').success?
  else
    try_for(60) do
      $vm.execute('systemctl --quiet is-active i2p').success?
    end
  end
end

Given /^I2P's reseeding (completed|started|failed)$/ do |progress|
  try_for(220) do
    $vm.execute("i2p_reseed_#{progress}", :libs => 'i2p').success?
  end
end

Given /^the I2P router console is ready$/ do
  try_for(120) do
    $vm.execute('i2p_router_console_is_ready', :libs => 'i2p').success?
  end
end

Then /^the I2P router console is displayed in I2P Browser$/ do
  @screen.wait('I2PRouterConsole.png', 2 * 60)
end

Then /^the I2P Browser desktop file is (not )?present$/ do |notpresent|
  file = '/usr/share/applications/i2p-browser.desktop'
  assert_equal(notpresent.nil?, $vm.execute("test -e #{file}").success?)
end

Then /^the I2P Browser sudo rules are (not )?present$/ do |notpresent|
  file = '/etc/sudoers.d/zzz_i2pbrowser'
  assert_equal(notpresent.nil?, $vm.execute("test -e #{file}").success?)
end

Then /^the I2P firewall rules are (enabled|disabled)$/ do |mode|
  i2p_username = 'i2psvc'
  i2p_uid = $vm.execute("getent passwd #{i2p_username} | awk -F ':' '{print $3}'").stdout.chomp
  accept_rules = $vm.execute("iptables -L -n -v | grep -E '^\s+[0-9]+\s+[0-9]+\s+ACCEPT.*owner UID match #{i2p_uid}$'").stdout
  accept_rules_count = accept_rules.lines.count
  if mode == 'enabled'
    assert_equal(13, accept_rules_count)
    step 'the firewall is configured to only allow the clearnet, i2psvc and debian-tor users to connect directly to the Internet over IPv4'
  else
    assert_equal(0, accept_rules_count)
    step 'the firewall is configured to only allow the clearnet and debian-tor users to connect directly to the Internet over IPv4'
  end
end

Then /^I2P is running in hidden mode$/ do
  @screen.wait("I2PNetworkHidden.png", 10)
end

Then /^I block the I2P router console port$/ do
  step 'process "nc" is not running'
  $vm.spawn("nc -l -p 7657 -t 127.0.0.1")
  step 'process "nc" is running within 5 seconds'
end

Then /^the I2P homepage loads in I2P Browser$/ do
  recovery_on_failure = Proc.new do
    $vm.focus_window('I2P Browser')
    begin
      @screen.click('BrowserReloadButton.png')
    rescue FindFailed
      @screen.type(Sikuli::Key.ESC)
      @screen.click('BrowserReloadButton.png')
    end
  end
  retry_i2p(recovery_on_failure) do
    $vm.focus_window('I2P Browser')
    visible, _ = @screen.waitAny(['I2PBrowserProjectHomepage.png', 'BrowserReloadButton.png'], 120)
    unless visible == 'I2PBrowserProjectHomepage.png'
      raise "Did not find 'I2PBrowserProjectHomepage.png'"
    end
  end
end

Then /^I see a notification that I2P failed to start$/ do
  robust_notification_wait('I2PFailedToStart.png', 2 * 60)
end

Then /^I see shared client tunnels in the I2P router console$/ do
  @screen.wait('I2PSharedClientTunnels.png', 15 * 60)
end

Then /^I see a notification that I2P is not ready$/ do
  robust_notification_wait('I2PBootstrapFailure.png', 4 * 60)
end
