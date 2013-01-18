When /^I open a new tab in Iceweasel$/ do
  @screen.type("t", Sikuli::KEY_CTRL)
end

When /^I open the address "([^"]*)" in Iceweasel$/ do |address|
  @screen.type("l", Sikuli::KEY_CTRL)
  @screen.type(address + Sikuli::KEY_RETURN)
end
