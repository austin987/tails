Then /^I should be able to run administration commands as the live user$/ do
  stdout = @vm.execute("echo #{@sudo_password} | sudo -S whoami", $live_user).stdout
  assert(stdout.sub(/^\[sudo\] password for #{$live_user}: /, "") == "root\n",
         "Could not use sudo")
end

Then /^I should not be able to run administration commands as the live user$/ do
  stderr = @vm.execute("echo | sudo -S whoami", $live_user).stderr
  assert(stderr.include?("The administration password is disabled"),
         "The administration password is not disabled")
end

Then /^I should be able to run synaptic$/ do
  step "I run \"gksu synaptic\""
  step "I enter the sudo password in the PolicyKit prompt"
  try_for(10, :msg => "Unable to start synaptic using PolicyKit") {
    @vm.has_process?("synaptic")
  }
end

Then /^I should not be able to run synaptic$/ do
  for p in ["", "live", $live_user]
    step "I run \"gksu synaptic\""
    @sudo_password = p
    step "I enter the sudo password in the PolicyKit prompt"
  end
  assert(!@vm.has_process?("synaptic"),
         "Synaptic started despite administration being disabled")
end
