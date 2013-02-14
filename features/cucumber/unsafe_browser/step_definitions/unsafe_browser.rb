When /^I see and accept the Unsafe Browser start verification$/ do
  @screen.wait("UnsafeBrowserStartVerification.png", 10)
  @screen.type("l", Sikuli::KEY_ALT)
end

Then /^I see and close the Unsafe Browser start notification$/ do
  @screen.wait("UnsafeBrowserStartNotification.png", 10)
  @screen.click("UnsafeBrowserStartNotification.png")
end

Then /^the Unsafe Browser has started$/ do
  @screen.wait("UnsafeBrowserWindow.png", 30)
end

Then /^the Unsafe Browser has a red theme$/ do
  @screen.wait("UnsafeBrowserRedTheme.png", 10)
end

Then /^the Unsafe Browser has Wikipedia pre-selected in the search bar$/ do
  @screen.wait("UnsafeBrowserSearchBar.png", 10)
end

Then /^the Unsafe Browser shows a warning as its start page$/ do
  @screen.wait("UnsafeBrowserStartPage.png", 10)
end

When /^I start the Unsafe Browser$/ do
  step "I run \"gksu unsafe-browser\""
  step "I see and accept the Unsafe Browser start verification"
  step "I see and close the Unsafe Browser start notification"
  step "the Unsafe Browser has started"
end

Then /^I see a warning about another instance already running$/ do
  @screen.wait('UnsafeBrowserWarnAlreadyRunning.png', 10)
end

When /^close the Unsafe Browser$/ do
  @screen.type("q", Sikuli::KEY_CTRL)
end

Then /^I see the Unsafe Browser stop notification$/ do
  @screen.wait('UnsafeBrowserStopNotification.png', 20)
  @screen.waitVanish('UnsafeBrowserStopNotification.png', 20)
end

Then /^I can start the Unsafe Browser again$/ do
  step "I start the Unsafe Browser"
end

When /^I open a new tab in the Unsafe Browser$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("UnsafeBrowserWindow.png", 10)
  @screen.click("UnsafeBrowserWindow.png")
  @screen.type("t", Sikuli::KEY_CTRL)
end

When /^I open the address "([^"]*)" in the Unsafe Browser$/ do |address|
  next if @skip_steps_while_restoring_background
  step "I open a new tab in the Unsafe Browser"
  @screen.type("l", Sikuli::KEY_CTRL)
  @screen.type(address + Sikuli::KEY_RETURN)
end
