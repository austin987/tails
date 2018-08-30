Then /^I am notified the ASP installation service is starting$/  do
  #title = "Installing your additional software from persistent storage"
  #step "I see the \"#{title}\" notification after at most 120 seconds"
  # Hairy, but this notification disappears as promptly as the APT install
  # command is finished, thus it vanishes sometimes too fast for the Dogtail
  # based sniffing to catch this notification at this stage of the GNOME
  # session startup. Meanwhile let's try to grossly find it in the journal so
  # that we at least know it has been fired up. There's maybe a UX problem
  # that may need fixing in ASP itself. 
  try_for(120) do
      !$vm.execute(
        "journalctl -a | grep \"/usr/local/lib/tails-additional-software-notify Installing your additional software from persistent storage \""
      ).stdout.empty?
  end
end

Then /^the additional software package (upgrade|installation) service has started$/ do |service|
  if !$vm.file_empty?('/live/persistence/TailsData_unlocked/live-additional-software.conf')
    case service
    when "installation"
      state_file = "/run/live-additional-software/installed"
      seconds_to_wait = 300
    when "upgrade"
      state_file = "/run/live-additional-software/upgraded"
      seconds_to_wait = 900
    end
    if !$vm.file_exist?(state_file)
      #step "I am notified the ASP installation service is starting"
      try_for(seconds_to_wait) do
        $vm.file_exist?(state_file)
      end
      step "I am notified that the installation succeeded"
    end
  end
end

Then /^I am notified I can not use ASP for "([^"]*)"$/  do |package|
  title = "You could install #{package} automatically when starting Tails"
  step "I see the \"#{title}\" notification after at most 300 seconds"
end

Then /^I am notified that the installation succeeded$/  do
  title = "Additional software installed successfully"
  step "I see the \"#{title}\" notification after at most 300 seconds"
end

Then /^I am notified the "([^"]*)" failed$/  do |service|
  case service
  when "ASP installation service"
    title = "The installation of your additional software failed"
    step "I see the \"#{title}\" notification after at most 300 seconds"
  when "ASP upgrade service"
    title = "The upgrade of your additional software failed"
    step "I see the \"#{title}\" notification after at most 300 seconds"
  end
end

Then /^I am proposed to create an ASP persistence for the "([^"]*)" package$/  do |package|
  title = "Add #{package} to your additional software?"
  step "I see the \"#{title}\" notification after at most 300 seconds"
end

Then /^I create the ASP persistence$/  do
  gnome_shell = Dogtail::Application.new('gnome-shell')
  gnome_shell.child('Create Persistent Storage', roleName: 'push button').click
  step 'I create a persistent partition for ASP'
  step 'The ASP persistence option is enabled'
  step 'I save and exit from the Persistence Wizard'
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
    step "I see the \"#{title}\" notification after at most 300 seconds"
    case decision
    when "confirm"
      gnome_shell.child('Install Every Time', roleName: 'push button').click
      try_for(30) do
        step "the ASP persistence is correctly configured for package \"#{package}\""
      end
    when "deny"
      gnome_shell.child('Install Only Once', roleName: 'push button').click
      step "\"#{package}\" is not part of ASP persistence configuration"
    end
  when "remove"
    title = "Remove #{package} from your additional software?"
    step "I see the \"#{title}\" notification after at most 300 seconds"
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

Given /^I remove "([^"]*)" from the list of ASP packages$/  do |package|
  @asp_gui = Dogtail::Application.new('tails-additional-software-config')
  installed_package = @asp_gui.child(package, roleName: 'label')
  installed_package.parent.parent.child('Close', roleName: 'push button').click
  @asp_gui.child('Question', roleName: 'alert').button('Remove').click
  deal_with_polkit_prompt(@sudo_password)
  try_for(120) do
    step "\"#{package}\" is not part of ASP persistence configuration"
  end
end

When /^I prepare the ASP upgrade process to fail$/  do
  pending # Write code here that turns the phrase above into concrete actions
end

When /^I remove the "([^"]*)" deb file from the APT cache$/  do |package|
  $vm.execute("rm -f /live/persistence/TailsData_unlocked/apt/cache/#{package}*.deb")
end

Then /^I can open the documentation from the notification link$/  do
  gnome_shell = Dogtail::Application.new('gnome-shell')
  gnome_shell.child('Documentation', roleName: 'push button').click
  # For some reason the below two steps fail. Dogtail can not find the Firefox
  # application.
  #try_for(60) { @torbrowser = Dogtail::Application.new('Firefox') }
  #step '"Install from another Tails" has loaded in the Tor Browser'
  # So instead let's try to find the title of the page with Sikuli.
  @screen.wait('ASPDocumentationInstallCloning', 120)
end

Then /^ASP has been started for "([^"]*)" and shuts up because the persistence is locked$/ do |package|
  asp_logs = '/run/live-additional-software/log'
  assert(!$vm.file_empty?(asp_logs))
  try_for(60) { $vm.execute("grep #{package} #{asp_logs}").success? }
  try_for(60) { $vm.file_content(asp_logs).include?('Warning: persistence storage is locked') }
end
