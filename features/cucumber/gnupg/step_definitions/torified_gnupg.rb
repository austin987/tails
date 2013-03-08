When /^I successfully fetch a GnuPG key using the CLI$/ do
  next if @skip_steps_while_restoring_background
  res = @vm.execute("gpg --recv-key 52B69F10A3B0785AD05AFB471D84CCF010CC5BC7",
                    "amnesia")
  assert(res.success?, "gpg keyserver fetch failed:\n#{res.stderr}")
end

When /^I successfully fetch a GnuPG key using seahorse$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("SeahorseWindow.png", 10)
  @screen.type("r", Sikuli::KEY_ALT) # Menu: "Remote" ->
  @screen.type("f")                  # "Find Remote Keys...".
  @screen.wait("SeahorseFindKeysWindow.png", 10)
  # Seahorse doesn't seem to support searching for fingerprints
  @screen.type("10CC5BC7" + Sikuli::KEY_RETURN)
  @screen.wait("SeahorseFoundKeyResult.png", 5*60)
  @screen.type(Sikuli::DOWN_ARROW)   # Select first item in result menu
  @screen.type("f", Sikuli::KEY_ALT) # Menu: "File" ->
  @screen.type("i")                  # "Import"
  try_for(120, :msg => "Failed to fetch key using seahorse") {
    @vm.execute("gpg --list-key 10CC5BC7", "amnesia").success?
  }
end
