Then /^I should be able to run administration commands as the live user$/ do
  next if @skip_steps_while_restoring_background
  stdout = @vm.execute("echo #{@sudo_password} | sudo -S whoami", $live_user).stdout
  actual_user = stdout.sub(/^\[sudo\] password for #{$live_user}: /, "").chomp
  assert_equal("root", actual_user, "Could not use sudo")
end

Then /^I should not be able to run administration commands as the live user with the "([^"]*)" password$/ do |password|
  next if @skip_steps_while_restoring_background
  stderr = @vm.execute("echo #{password} | sudo -S whoami", $live_user).stderr
  sudo_failed = stderr.include?("The administration password is disabled") || stderr.include?("is not allowed to execute")
  assert(sudo_failed, "The administration password is not disabled:" + stderr)
end

When /^running a command as root with pkexec requires PolicyKit administrator privileges$/ do
  next if @skip_steps_while_restoring_background
  action = 'org.freedesktop.policykit.exec'
  action_details = @vm.execute("pkaction --verbose --action-id #{action}").stdout
  assert(action_details[/\s+implicit any:\s+auth_admin$/],
         "Expected 'auth_admin' for 'any':\n#{action_details}")
  assert(action_details[/\s+implicit inactive:\s+auth_admin$/],
         "Expected 'auth_admin' for 'inactive':\n#{action_details}")
  assert(action_details[/\s+implicit active:\s+auth_admin$/],
         "Expected 'auth_admin' for 'active':\n#{action_details}")
end

Then /^I should be able to run a command as root with pkexec$/ do
  next if @skip_steps_while_restoring_background
  step "I run \"pkexec touch /root/pkexec-test\" in GNOME Terminal"
  step 'I enter the sudo password in the pkexec prompt'
  try_for(10, :msg => 'The /root/pkexec-test file was not created.') {
    @vm.execute('ls /root/pkexec-test').success?
  }
end

Then /^I should not be able to run a command as root with pkexec and the standard passwords$/ do
  next if @skip_steps_while_restoring_background
  step "I run \"pkexec touch /root/pkexec-test\" in GNOME Terminal"
  ['', 'live'].each do |password|
    step "I enter the \"#{password}\" password in the pkexec prompt"
    @screen.wait('PolicyKitAuthFailure.png', 20)
  end
  step "I enter the \"amnesia\" password in the pkexec prompt"
  @screen.wait('PolicyKitAuthCompleteFailure.png', 20)
end
