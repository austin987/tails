require 'uri'

Given /^APT's sources are only \{ftp.us,security,back-ports\}\.debian\.org$/ do
  next if @skip_steps_while_restoring_background
  @vm.execute("cat /etc/apt/sources.list").stdout.each_line { |line|
    next if ! line.start_with? "deb"
    source = line.split[1]
    source_host = URI(source).host
    if source_host != "ftp.us.debian.org" and \
       source_host != "security.debian.org" and \
       source_host != "backports.debian.org"
      raise "Bad APT source '#{source}'"
    end
  }
end

When /^I update APT using apt-get$/ do
  SystemTimer.timeout(30*60) do
    assert @vm.execute("echo #{@sudo_password} | sudo -S apt-get update", "amnesia").success?
  end
end

Then /^I should be able to install a package using apt-get$/ do
  package = "cowsay"
  SystemTimer.timeout(120) do
    @vm.execute("echo #{@sudo_password} | " +
                "sudo -S apt-get install #{package}", "amnesia")
  end
  step "package \"#{package}\" is installed"
end

When /^I update APT using synaptic$/ do
  # Upon start the interface will be frozen while synaptic loads the
  # package list
  try_for(20) { @screen.click('SynapticReload.png') }
  @screen.wait('SynapticReloadPrompt.png', 20)
  @screen.waitVanish('SynapticReloadPrompt.png', 30*60)
end

Then /^I should be able to install a package using synaptic$/ do
  package = "cowsay"
  # We do this after a Reload, so the interface will be frozen until
  # the package list has been loaded
  try_for(20) {
    @screen.type("f", Sikuli::KEY_CTRL)  # Find key
    @screen.find('SynapticSearch.png')
  }
  @screen.type(package + Sikuli::KEY_RETURN)
  @screen.wait('SynapticCowsaySearchResult.png', 20)
  @screen.click('SynapticCowsaySearchResult.png')
  sleep 1
  @screen.type("i", Sikuli::KEY_CTRL)    # Mark for installation
  sleep 1
  @screen.type("p", Sikuli::KEY_CTRL)    # Apply
  @screen.wait('SynapticApplyPrompt.png', 20)
  @screen.type("a", Sikuli::KEY_ALT)     # Verify apply
  @screen.wait('SynapticChangesAppliedPrompt.png', 120)
  step "package \"#{package}\" is installed"
end
