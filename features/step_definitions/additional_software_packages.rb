When /^I configure additional software packages to install "(.+?)"$/ do |package|
  $vm.file_overwrite(
    '/live/persistence/TailsData_unlocked/live-additional-software.conf',
    package + "\n"
  )
end

Then /^I am notified the ASP installation service is starting$/  do
  title = "Installing your additional software from persistent storage…"
  step "the \"#{title}\" notification is shown to the user"
end

Then /^the additional software package (upgrade|installation) service has started$/ do |service|
  case service
  when "installation"
    step "I am notified the ASP installation service is starting"
    try_for(300) do
      $vm.file_exist?('/run/live-additional-software/installed')
    end
  when "upgrade"
    try_for(300) do
      $vm.file_exist?('/run/live-additional-software/upgraded')
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
  case service
  when "ASP installation service"
    title = "The installation of your additional software failed"
    step "the \"#{title}\" notification is shown to the user"
  when "ASP upgrade service"
    title = "The upgrade of your additional software failed"
    step "the \"#{title}\" notification is shown to the user"
  end
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
  asp_conf = '/live/persistence/TailsData_unlocked/live-additional-software.conf'
  assert($vm.file_exist?(asp_conf), "ASP configuration file not found")
  step 'all persistence configuration files have safe access rights'
  assert($vm.execute("grep #{package} #{asp_conf}").success?)
  $vm.execute("ls /live/persistence/TailsData_unlocked/apt/cache/ | grep -qs '^#{package}.*\.deb$'").success?
  $vm.execute("ls /live/persistence/TailsData_unlocked/apt/lists/ | grep -qs '^.*_Packages$'").success?
end

Then /^"([^"]*)" is not part of ASP persistence configuration$/ do |package|
  asp_conf = '/live/persistence/TailsData_unlocked/live-additional-software.conf'
  assert($vm.file_exist?(asp_conf), "ASP configuration file not found")
  step 'all persistence configuration files have safe access rights'
  $vm.execute("grep \"#{package}\" #{asp_conf}").stdout.empty?
end

When /^I (deny|confirm) when I am asked if I want to (add|remove) "([^"]*)" (to|from) ASP configuration$/  do |decision, action, package, destination|
  gnome_shell = Dogtail::Application.new('gnome-shell')
  case action
  when "add"
    title = "Add #{package} to your additional software?"
    step "the \"#{title}\" notification is shown to the user"
    case decision
    when "confirm"
      gnome_shell.child('Add to Persistent Storage', roleName: 'push button').click
      try_for(30) do
        step "the ASP persistence is correctly configured for package \"#{package}\""
      end
    when "deny"
      gnome_shell.child('Install only once', roleName: 'push button').click
      step "\"#{package}\" is not part of ASP persistence configuration"
    end
  when "remove"
    title = "Remove #{package} from your additional software?"
    step "the \"#{title}\" notification is shown to the user"
    step "the ASP persistence is correctly configured for package \"#{package}\""
    case decision
    when "confirm"
      gnome_shell.child('Remove', roleName: 'push button').click
      try_for(30) do
        step "\"#{package}\" is not part of ASP persistence configuration"
      end
    when "deny"
      gnome_shell.child('Cancel', roleName: 'push button').click
      step "the ASP persistence is correctly configured for package \"#{package}\""
    end
  end
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
