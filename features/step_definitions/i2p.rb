When /^I start I2P through the GNOME menu$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("GnomeApplicationsMenu.png", 10)
  @screen.wait_and_click("GnomeApplicationsInternet.png", 10)
  @screen.wait_and_click("GnomeApplicationsI2P.png", 20)
end

Then /^the I2P desktop file is (|not )present$/ do |mode|
  next if @skip_steps_while_restoring_background
  file = '/usr/share/applications/i2p.desktop'
  if mode == ''
    assert(@vm.execute("test -e #{file}").success?)
  elsif mode == 'not '
    assert(@vm.execute("! test -e #{file}").success?)
  else
    raise "Unsupported mode passed: '#{mode}'"
  end
end

Then /^the I2P sudo rules are (enabled|not present)$/ do |mode|
  next if @skip_steps_while_restoring_background
  file = '/etc/sudoers.d/zzz_i2p'
  if mode == 'enabled'
    assert(@vm.execute("test -e #{file}").success?)
  elsif mode == 'not present'
    assert(@vm.execute("! test -e #{file}").success?)
  else
    raise "Unsupported mode passed: '#{mode}'"
  end
end

Then /^the I2P firewall rules are (enabled|disabled)$/ do |mode|
  next if @skip_steps_while_restoring_background
  i2p_username = 'i2psvc'
  i2p_uid = @vm.execute("getent passwd #{i2p_username} | awk -F ':' '{print $3}'").stdout.chomp
  accept_rules = @vm.execute("iptables -L -n -v | grep -E '^\s+[0-9]+\s+[0-9]+\s+ACCEPT.*owner UID match #{i2p_uid}$'").stdout
  accept_rules_count = accept_rules.lines.count
  if mode == 'enabled'
    assert_equal(accept_rules_count, 13)
  elsif mode == 'disabled'
    assert_equal(accept_rules_count, 0)
  else
    raise "Unsupported mode passed: '#{mode}'"
  end
end
