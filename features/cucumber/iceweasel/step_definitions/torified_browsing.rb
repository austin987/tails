def restore_background
  @vm.restore_snapshot(@background_snapshot)
  # Wait for virt-viewer to be available to sikuli. Otherwise we could
  # lose sikuli actions (e.g. key presses) if they come really early
  # after the restore
  @screen.wait("IceweaselRunning.png", 10)

  # The guest's Tor's circuits' states are likely to get out of sync
  # with the other relays, so we ensure that we have fresh circuits.
  # Time jumps and incorrect clocks also confuses Tor in many ways.
  wait_until_remote_shell_is_up
  @vm.execute("service tor stop", "root")
  @vm.execute("killall vidalia")
  @vm.host_to_guest_time_sync
  @vm.execute("service tor start", "root")
  wait_until_tor_is_working
end

When /^I open a new tab in Iceweasel$/ do
  @screen.type("t", Sikuli::KEY_CTRL)
end

When /^I open the address "([^"]*)" in Iceweasel$/ do |address|
  @screen.type("l", Sikuli::KEY_CTRL)
  @screen.type(address + Sikuli::KEY_RETURN)
end
