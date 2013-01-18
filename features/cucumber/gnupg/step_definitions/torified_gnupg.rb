def restore_background
  @vm.restore_snapshot(@background_snapshot)

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

When /^I successfully fetch a GnuPG key using the CLI$/ do
  @vm.execute("gpg --recv-key 52B69F10A3B0785AD05AFB471D84CCF010CC5BC7").success?
end

When /^I successfully fetch a GnuPG key using seahorse$/ do
  @screen.type("r", Sikuli::KEY_ALT) # Menu: "Remote" ->
  @screen.type("f")                  # "Find Remote Keys...".
  @screen.wait("SeahorseFindKeysWindow.png", 10)
  # Seahorse doesn't seem to support searching for fingerprints
  @screen.type("10CC5BC7" + Sikuli::KEY_RETURN)
  @screen.wait("SeahorseFoundKeyResult.png", 120)
  @screen.type(Sikuli::DOWN_ARROW)   # Select first item in result menu
  @screen.type("f", Sikuli::KEY_ALT) # Menu: "File" ->
  @screen.type("i")                  # "Import"
  try_for(120) { @vm.execute("gpg --list-key 10CC5BC7").success? }
end
