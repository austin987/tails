When /^I open a new tab in Iceweasel$/ do
  next if @skip_steps_while_restoring_background
  @screen.type("t", Sikuli::KEY_CTRL)
end

When /^I open the address "([^"]*)" in Iceweasel$/ do |address|
  next if @skip_steps_while_restoring_background
  @screen.type("l", Sikuli::KEY_CTRL)
  @screen.type(address + Sikuli::KEY_RETURN)
end
