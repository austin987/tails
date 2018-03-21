When /^I configure additional software packages to install "(.+?)"$/ do |package|
  $vm.file_overwrite(
    '/live/persistence/TailsData_unlocked/live-additional-software.conf',
    package + "\n"
  )
end

Then /^the additional software package (upgrade|installation) service is run$/ do |service|
  case service
  when "installation"
    try_for(300) do
      $vm.file_exist?('/run/live-additional-software/installed')
    end
  when "upgrade"
    try_for(300) do
      $vm.file_exist?('/run/live-additional-software/installed')
    end
  end
end

Then /^I am notified I can not use ASP for "([^"]*)"$/  do |package|
  title = "You could install #{package} automatically when starting Tails"
  step "the \"#{title}\" notification is shown to the user"
end

Then /^I am notified that the installation succeeded$/  do
    title = "Additional software installed successfully"
    step "the \"#{title}\" notification is shown to the user"
end

Then /^I am notified the "([^"]*)" failed$/  do |service|
  pending # Write code here that turns the phrase above into concrete actions
end

Then /^I am proposed to create an ASP persistence for the "([^"]*)" package$/  do |package|
  title = "Add #{package} to your additional software?"
  step "the \"#{title}\" notification is shown to the user"
end

Then /^I create the ASP persistence$/  do
  gnome_shell = Dogtail::Application.new('gnome-shell')
  gnome_shell.child('Create Persistent Storage', roleName: 'push button').click
  step 'I create a persistent partition for ASP'
  step 'The ASP persistence option is enabled'
  step 'I save and exit from the Persistence Wizard'
  # Temporary fix for #15340
  $vm.execute('chmod 644 /media/tails-persistence-setup/TailsData/live-additional-software.conf')
  # Workaround #15431
  $vm.execute('mkdir -p /media/tails-persistence-setup/TailsData/apt && rsync -a /var/cache/apt/archives/ /media/tails-persistence-setup/TailsData/apt/cache/ && cp -a /var/lib/apt/lists /media/tails-persistence-setup/TailsData/apt/')
end

Then /^The ASP persistence option is enabled$/  do
  @screen.wait('ASPPersistenceSetupOptionEnabled', 60)
end

Then /^the ASP persistence is correctly configured for package "([^"]*)"$/ do |package|
  assert($vm.file_exist?('/live/persistence/TailsData_unlocked/live-additional-software.conf'))
  assert_equal($vm.file_content('/live/persistence/TailsData_unlocked/live-additional-software.conf').chomp, package)
  assert($vm.execute("ls /live/persistence/TailsData_unlocked/apt/cache/ | grep -qs \'^#{package}.*\.deb$\'").success?)
  assert($vm.execute("ls /live/persistence/TailsData_unlocked/apt/lists/ | grep -qs \'^.*_Packages$\'").success?)
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
