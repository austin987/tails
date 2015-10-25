Given /^I2P is (?:still )?(not )?running$/ do |notrunning|
  if notrunning
    !$vm.execute('service i2p status').success?
  else
    try_for(30) do
      $vm.execute('service i2p status').success?
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
  if notpresent
    assert($vm.execute("! test -e #{file}").success?)
  else
    assert($vm.execute("test -e #{file}").success?)
  end
end

Then /^the I2P Browser sudo rules are (enabled|not present)$/ do |mode|
  file = '/etc/sudoers.d/zzz_i2pbrowser'
  if mode == 'enabled'
    assert($vm.execute("test -e #{file}").success?)
  else
    assert($vm.execute("! test -e #{file}").success?)
  end
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
    @screen.type(Sikuli::Key.ESC)
    @screen.click('BrowserReloadButton.png')
  end
  retry_i2p(recovery_on_failure) do
    $vm.focus_window('I2P Browser')
    @screen.wait('I2PBrowserProjectHomepage.png', 80)
  end
end

Then /^I see a notification that I2P failed to start$/ do
  notification_helper('I2PFailedToStart.png', 2 * 60)
end

Then /^I2P successfully built a tunnel$/ do
  try_for(7 * 60) do
    $vm.execute('i2p_built_a_tunnel', :libs => 'i2p').success?
  end
end

Then /^I see a notification that I2P is not ready$/ do
  notification_helper('I2PBootstrapFailure.png', 4 * 60)
end
