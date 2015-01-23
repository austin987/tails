When /^I open a new tab in the Tor Browser$/ do
  next if @skip_steps_while_restoring_background
  @screen.click("TorBrowserNewTabButton.png")
  @screen.wait("TorBrowserAddressBar.png", 10)
end

When /^I open the address "([^"]*)" in the Tor Browser$/ do |address|
  next if @skip_steps_while_restoring_background
  step "I open a new tab in the Tor Browser"
  @screen.click("TorBrowserAddressBar.png")
  sleep 0.5
  @screen.type(address + Sikuli::Key.ENTER)
end
