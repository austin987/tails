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
    if service == "installation"
      step "I am notified that the installation succeeded"
    end
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

Then /^I am proposed to add the "([^"]*)" package to my Additional Software$/  do |package|
  title = "Add #{package} to your additional software?"
  step "I see the \"#{title}\" notification after at most 300 seconds"
end

Then /^I create a persistent storage and activate the Additional Software feature$/  do
  gnome_shell = Dogtail::Application.new('gnome-shell')
  gnome_shell.child('Create Persistent Storage', roleName: 'push button').click
  step 'I create a persistent partition for Additional Software'
  step 'The Additional Software persistence option is enabled'
  save_and_exit_the_persistence_wizard
end

Then /^The Additional Software persistence option is enabled$/  do
  @screen.wait('ASPPersistenceSetupOptionEnabled.png', 60)
end

Then /^Additional Software is correctly configured for package "([^"]*)"$/ do |package|
  try_for(30) do
    assert($vm.file_exist?(ASP_CONF), "ASP configuration file not found")
    step 'all persistence configuration files have safe access rights'
    $vm.execute_successfully("ls /live/persistence/TailsData_unlocked/apt/cache/#{package}_*.deb")
    $vm.execute_successfully("ls /live/persistence/TailsData_unlocked/apt/lists/*_Packages")
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
  case action
  when "adding"
    notification_title = "Add #{package} to your additional software?"
    case decision
    when "accept"
      button_title = 'Install Every Time'
    when "refuse"
      button_title = 'Install Only Once'
    end
  when "removing"
    notification_title = "Remove #{package} from your additional software?"
    case decision
    when "accept"
      button_title = 'Remove'
    when "refuse"
      button_title = 'Cancel'
    end
  end
  try_for(300) do
    notification =
      Dogtail::Application.new('gnome-shell')
        .children('', roleName: "notification")
        .find { |notif| notif.child?(notification_title, roleName: 'label') }
    assert_not_nil(notification)
    notification.child(button_title, roleName: 'push button').click
  end
end

Given /^I remove "([^"]*)" from the list of Additional Software using Additional Software GUI$/  do |package|
  asp_gui = Dogtail::Application.new('tails-additional-software-config')
  installed_package = asp_gui.child(package, roleName: 'label')
  installed_package.parent.parent.child('Remove', roleName: 'push button').click
  asp_gui.child('Question', roleName: 'alert').button('Remove').click
  deal_with_polkit_prompt(@sudo_password)
end

When /^I prepare the Additional Software upgrade process to fail$/  do
  # Remove the newest cowsay package from the APT cache with a DPKG hook
  # before it gets upgraded so that we simulate a failing upgrade.
  failing_dpkg_hook = <<-EOF
DPkg::Pre-Invoke {
  "ls -1 -v /var/cache/apt/archives/cowsay*.deb | tail -n 1 | xargs rm";
};
EOF
  $vm.file_overwrite('/etc/apt/apt.conf.d/00failingDPKGhook', failing_dpkg_hook)
  # Tell the upgrade service check step not to run
  $vm.execute_successfully("touch #{ASP_STATE_DIR}/doomed_to_fail")
end

When /^I remove the "([^"]*)" deb files from the APT cache$/  do |package|
  $vm.execute_successfully("rm /live/persistence/TailsData_unlocked/apt/cache/#{package}_*.deb")
end

Then /^I can open the Additional Software documentation from the notification$/  do
  gnome_shell = Dogtail::Application.new('gnome-shell')
  gnome_shell.child('Documentation', roleName: 'push button').click
  try_for(60) { @torbrowser = Dogtail::Application.new('Firefox') }
  step '"Tails - Install from another Tails" has loaded in the Tor Browser'
end

Then /^the Additional Software dpkg hook has been run for package "([^"]*)" and notices the persistence is locked$/ do |package|
  asp_logs = "#{ASP_STATE_DIR}/log"
  assert(!$vm.file_empty?(asp_logs))
  try_for(120) {$vm.execute("grep -E '^.*New\spackages\smanually\sinstalled:\s.*#{package}.*$' #{asp_logs}").success?}
  try_for(60) { $vm.file_content(asp_logs).include?('Warning: persistence storage is locked') }
end

When /^I can open the Additional Software configuration window from the notification$/ do
  gnome_shell = Dogtail::Application.new('gnome-shell')
  gnome_shell.child('Configure', roleName: 'push button').click
  asp = Dogtail::Application.new('tails-additional-software-config')
end

Then /^I can open the Additional Software log file from the notification$/ do
  gnome_shell = Dogtail::Application.new('gnome-shell')
  gnome_shell.child('Show Log', roleName: 'push button').click
  try_for(60) { Dogtail::Application.new('gedit').child("log [Read-Only] (#{ASP_STATE_DIR}) - gedit", roleName: 'frame') }
end
