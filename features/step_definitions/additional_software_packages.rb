When /^I configure additional software packages to install "(.+?)"$/ do |package|
  $vm.file_overwrite(
    '/live/persistence/TailsData_unlocked/live-additional-software.conf',
    package + "\n"
  )
end

Then /^the additional software package installation service is run$/ do
  try_for(300) do
    $vm.file_exist?('/run/live-additional-software/installed')
  end
end

Then /^I am notified I can not use ASP$/  do
  # XXX: Would be better to fetch the title from the po or source code files.
  title = "You could install sslh automatically when starting Tails"
  step "the \"#{title}\" notification is shown to the user"
end

Then /^I am notified that the package "([^"]*)" (is installed|has been upgraded)$/  do |package, status|
  pending # Write code here that turns the phrase above into concrete actions
end

Then /^I am notified the "([^"]*)" failed$/  do |service|
  pending # Write code here that turns the phrase above into concrete actions
end

Then /^I am proposed to create an ASP persistence$/  do
  pending # Write code here that turns the phrase above into concrete actions
end

Then /^I create the persistence$/  do
  pending # Write code here that turns the phrase above into concrete actions
end

# should be moved into the APT steps definition and factorized with the check for installation
When /^I uninstall "([^"]*)" using apt$/  do |package|
  pending # Write code here that turns the phrase above into concrete actions
end

# should be moved into the APT steps definition and factorized with the check for installation
When /^I install an old version "([^"]*)" of the "([^"]*)" package using apt$/  do |version, package|
  pending # Write code here that turns the phrase above into concrete actions
end

# should be moved into the APT steps definition and factorized with the check for installation
Then /^the package "([^"]*)" is not installed$/  do |package|
  pending # Write code here that turns the phrase above into concrete actions
end

When /^I (deny|confirm) when I am asked if I want to (add|remove) "([^"]*)" (to|from) ASP configuration$/  do |decision, action, package|
  pending # Write code here that turns the phrase above into concrete actions
end

When /^the package "([^"]*)" installed version is(| newer than) "([^"]*)"$/  do |package, comparison, version|
  pending # Write code here that turns the phrase above into concrete actions
end

When /^I remove the APT source for the old cowsay version$/  do
  pending # Write code here that turns the phrase above into concrete actions
end

Given /^I start the ASP GUI$/  do
  pending # Write code here that turns the phrase above into concrete actions
end

Given /^I remove "([^"]*)" from the list of ASP packages$/  do |package|
  pending # Write code here that turns the phrase above into concrete actions
end

When /^I prepare the ASP upgrade process to fail$/  do
  pending # Write code here that turns the phrase above into concrete actions
end

When /^I remove the "([^"]*)" deb file from the APT cache$/  do |package|
  pending # Write code here that turns the phrase above into concrete actions
end
