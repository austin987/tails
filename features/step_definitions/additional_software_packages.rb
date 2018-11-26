ASP_STATE_DIR = "/run/live-additional-software"
ASP_CONF = '/live/persistence/TailsData_unlocked/live-additional-software.conf'

Then /^the Additional Software (upgrade|installation) service has started$/ do |service|
  if $vm.file_exist?(ASP_CONF) and !$vm.file_empty?(ASP_CONF)
    case service
    when "installation"
      service = "tails-additional-software-install"
      seconds_to_wait = 600
    when "upgrade"
      service = "tails-additional-software-upgrade"
      seconds_to_wait = 900
    end
    try_for(seconds_to_wait, :delay => 10) do
      $vm.execute("systemctl status #{service}.service").success?
    end
    step "I am notified that the installation succeeded"
  end
end

Then /^I am notified I can not use Additional Software for "([^"]*)"$/  do |package|
  title = "You could install #{package} automatically when starting Tails"
  step "I see the \"#{title}\" notification after at most 300 seconds"
end

Then /^I am notified that the installation succeeded$/  do
  title = "Additional software installed successfully"
  step "I see the \"#{title}\" notification after at most 300 seconds"
end

Then /^I am proposed to create an Additional Software persistence for the "([^"]*)" package$/  do |package|
  title = "Add #{package} to your additional software?"
  step "I see the \"#{title}\" notification after at most 300 seconds"
end

Then /^I create the Additional Software persistence$/  do
  gnome_shell = Dogtail::Application.new('gnome-shell')
  gnome_shell.child('Create Persistent Storage', roleName: 'push button').click
  step 'I create a persistent partition for Additional Software'
  step 'The Additional Software persistence option is enabled'
  save_and_exit_the_persistence_wizard
end

Then /^The Additional Software persistence option is enabled$/  do
  @screen.wait('ASPPersistenceSetupOptionEnabled', 60)
end

Then /^Additional Software is correctly configured for package "([^"]*)"$/ do |package|
  assert($vm.file_exist?(ASP_CONF), "ASP configuration file not found")
  step 'all persistence configuration files have safe access rights'
  $vm.execute("ls /live/persistence/TailsData_unlocked/apt/cache/#{package}_*.deb").success?
  $vm.execute("ls /live/persistence/TailsData_unlocked/apt/lists/*_Packages").success?
  try_for(30) do
    $vm.execute("grep --line-regexp --fixed-strings #{package} #{ASP_CONF}").success?
  end
end

Then /^"([^"]*)" is not in the list of Additional Software$/ do |package|
  assert($vm.file_exist?(ASP_CONF), "ASP configuration file not found")
  step 'all persistence configuration files have safe access rights'
  try_for(30) do
    $vm.execute("grep \"#{package}\" #{ASP_CONF}").stdout.empty?
  end
end

When /^I (refuse|accept) (adding|removing) "([^"]*)" (?:to|from) Additional Software$/  do |decision, action, package|
  gnome_shell = Dogtail::Application.new('gnome-shell')
  case action
  when "adding"
    title = "Add #{package} to your additional software?"
    step "I see the \"#{title}\" notification after at most 300 seconds"
    case decision
    when "accept"
      gnome_shell.child('Install Every Time', roleName: 'push button').click
    when "refuse"
      gnome_shell.child('Install Only Once', roleName: 'push button').click
    end
  when "removing"
    title = "Remove #{package} from your additional software?"
    step "I see the \"#{title}\" notification after at most 300 seconds"
    case decision
    when "accept"
      gnome_shell.child('Remove', roleName: 'push button').click
    when "refuse"
      gnome_shell.child('Cancel', roleName: 'push button').click
    end
  end
end

Given /^I remove "([^"]*)" from the list of Additional Software using Additional Software GUI$/  do |package|
  asp_gui = Dogtail::Application.new('tails-additional-software-config')
  installed_package = asp_gui.child(package, roleName: 'label')
  installed_package.parent.parent.child('Close', roleName: 'push button').click
  asp_gui.child('Question', roleName: 'alert').button('Remove').click
  deal_with_polkit_prompt(@sudo_password)
end

When /^I prepare the Additional Software upgrade process to fail$/  do
  # Remove the newest cowsay package from the APT cache with a DPKG hook
  # before it gets upgraded so that we simulate a failing upgrade.
  failing_dpkg_hook = <<-EOF
DPkg::Pre-Invoke {
  "ls -tr1 /var/cache/apt/archives/cowsay*.deb | head -n 1 | xargs rm";
};
EOF
  $vm.file_overwrite('/etc/apt/apt.conf.d/00failingDPKGhook', failing_dpkg_hook)
  # Tell the upgrade service check step not to run
  $vm.execute("touch #{ASP_STATE_DIR}/doomed_to_fail")
end

When /^I remove the "([^"]*)" deb files from the APT cache$/  do |package|
  $vm.execute_successfully("rm /live/persistence/TailsData_unlocked/apt/cache/#{package}_*.deb")
  try_for(60) do
    $vm.execute("ls /live/persistence/TailsData_unlocked/apt/cache/#{package}_*.deb").failure?
  end
end

Then /^I can open the Additional Software documentation from the notification link$/  do
  gnome_shell = Dogtail::Application.new('gnome-shell')
  gnome_shell.child('Documentation', roleName: 'push button').click
  # For some reason the below two steps fail. Dogtail can not find the Firefox
  # application.
  #try_for(60) { @torbrowser = Dogtail::Application.new('Firefox') }
  #step '"Install from another Tails" has loaded in the Tor Browser'
  # So instead let's try to find the title of the page with Sikuli.
  @screen.wait('ASPDocumentationInstallCloning.png', 120)
end

Then /^the Additional Software dpkg hook has been run for package "([^"]*)" and notices the persistence is locked$/ do |package|
  asp_logs = "#{ASP_STATE_DIR}/log"
  assert(!$vm.file_empty?(asp_logs))
  try_for(60) { $vm.execute("grep -E '^.*New\spackages\smanually\sinstalled:\s.*#{package}.*$' #{asp_logs}").success? }
  try_for(60) { $vm.file_content(asp_logs).include?('Warning: persistence storage is locked') }
end

When /^I can open the Additional Software configuration window from the notification$/ do
  gnome_shell = Dogtail::Application.new('gnome-shell')
  gnome_shell.child('Configure', roleName: 'push button').click
  asp = Dogtail::Application.new('tails-additional-software-config')
end

When /^I disable the Additional Software installation service$/ do
  $vm.execute_successfully('systemctl disable tails-additional-software-install.service')
end

When /^I start the Additional Software installation service$/ do
  $vm.execute_successfully('systemctl enable tails-additional-software-install.service')
  $vm.execute_successfully('systemctl --no-block start tails-additional-software-install.service')
end

Then /^I can open the Additional Software log file from the notification$/ do
  gnome_shell = Dogtail::Application.new('gnome-shell')
  gnome_shell.child('Show Log', roleName: 'push button').click
  try_for(60) { gedit = Dogtail::Application.new('gedit').child("log [Read-Only] (#{ASP_STATE_DIR}) - gedit", roleName: 'frame') }
end
