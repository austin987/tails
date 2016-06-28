require 'uri'

Given /^the only hosts in APT sources are "([^"]*)"$/ do |hosts_str|
  hosts = hosts_str.split(',')
  $vm.file_content("/etc/apt/sources.list /etc/apt/sources.list.d/*").chomp.each_line { |line|
    next if ! line.start_with? "deb"
    source_host = URI(line.split[1]).host
    if !hosts.include?(source_host)
      raise "Bad APT source '#{line}'"
    end
  }
end

When /^I update APT using apt$/ do
  Timeout::timeout(30*60) do
    $vm.execute_successfully("echo #{@sudo_password} | " +
                             "sudo -S apt update", :user => LIVE_USER)
  end
end

Then /^I should be able to install a package using apt$/ do
  package = "cowsay"
  Timeout::timeout(120) do
    $vm.execute_successfully("echo #{@sudo_password} | " +
                             "sudo -S apt install #{package}",
                             :user => LIVE_USER)
  end
  step "package \"#{package}\" is installed"
end

When /^I update APT using Synaptic$/ do
  recovery_proc = Proc.new do
    $vm.execute("killall synaptic")
    step "I start Synaptic"
  end
  retry_tor(recovery_proc) do
    try_for(60, :msg => "Failed to trigger the reload of the package list") {
      # here using the Synaptic keyboard shortcut is more effective on retries.
      @screen.type("r", Sikuli::KeyModifier.CTRL)
      @screen.wait('SynapticReloadPrompt.png', 10)
    }
    try_for(900, :msg => "Took too much time to download the APT data") {
      !$vm.execute("pidof /usr/lib/apt/methods/tor+http").success?
    }
    if @screen.exists('SynapticFailure.png')
      raise "Updating APT with Synaptic failed."
    end
  end
end

Then /^I should be able to install a package using Synaptic$/ do
  package = "cowsay"
  try_for(60) do
    @screen.wait_and_click('SynapticSearchButton.png', 10)
    @screen.wait_and_click('SynapticSearchWindow.png', 10)
  end
  @screen.type(package + Sikuli::Key.ENTER)
  @screen.wait_and_double_click('SynapticCowsaySearchResult.png', 20)
  @screen.wait_and_click('SynapticApplyButton.png', 10)
  @screen.wait('SynapticApplyPrompt.png', 60)
  @screen.type(Sikuli::Key.ENTER)
  @screen.wait('SynapticChangesAppliedPrompt.png', 240)
  step "package \"#{package}\" is installed"
end

When /^I start Synaptic$/ do
  step 'I start "Synaptic Package Manager" via the GNOME "System Tools" applications menu'
  deal_with_polkit_prompt('PolicyKitAuthPrompt.png', @sudo_password)
  @screen.wait('SynapticReloadButton.png', 30)
end
