When /^I open a new tab in Iceweasel$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("IceweaselRunning.png", 10)
  @screen.type("t", Sikuli::KEY_CTRL)
end

When /^I open the address "([^"]*)" in Iceweasel$/ do |address|
  next if @skip_steps_while_restoring_background
  step "I open a new tab in Iceweasel"
  @screen.type("l", Sikuli::KEY_CTRL)
  sleep 0.5
  @screen.type(address + Sikuli::KEY_RETURN)
end
