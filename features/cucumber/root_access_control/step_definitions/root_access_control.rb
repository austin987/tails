Then /^I should be able to run administration commands as amnesia$/ do
  stdout = @vm.execute("echo #{@password} | sudo -S whoami", "amnesia").stdout
  assert stdout.sub(/^\[sudo\] password for amnesia: /, "") == "root\n"
end

Then /^I should not be able to run administration commands as amnesia$/ do
  stderr = @vm.execute("echo | sudo -S whoami", "amnesia").stderr
  assert stderr.include?("The administration password is disabled")
end

Then /^I should be able to run synaptic$/ do
  step "I run \"gksu synaptic\""
  step "I enter the sudo password in the PolicyKit prompt"
  try_for(10) { guest_has_process?("synaptic") }
end

Then /^I should not be able to run synaptic$/ do
  for p in ["", "live", "amnesia"]
    step "I run \"gksu synaptic\""
    @password = p
    step "I enter the sudo password in the PolicyKit prompt"
  end
  assert !guest_has_process?("synaptic")
end
