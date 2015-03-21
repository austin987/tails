def read_and_validate_ssh_config
  @secret_ssh_key = $config["SSH"]["private_key"]
  @public_ssh_key = $config["SSH"]["public_key"]
  @ssh_username   = $config["SSH"]["username"]
  @ssh_host       = $config["SSH"]["hostname"]
  @ssh_port       = $config["SSH"]["port"].to_i if $config["SSH"]["port"]

  assert(@secret_ssh_key && @secret_ssh_key.length > 0, "private_key must be set.")
  assert(@public_ssh_key && @public_ssh_key.length > 0, "public_key must be set.")

  assert(@ssh_username && @ssh_username.length > 0, "username not set.")
  assert(@ssh_host && @ssh_host.length > 0, "hostname not set.")
  assert(!@ssh_host.match(/^(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))/), "#{@ssh_host} " +
       "looks like a LAN IP address.")
end

Given /^I have the SSH key pair for an? (Git repository|SSH server) on the Internet$/ do |server_type|
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("install -m 0700 -d '/home/#{LIVE_USER}/.ssh/'", LIVE_USER)
  case server_type
  when "SSH server"
    read_and_validate_ssh_config
  when "Git repository"
    @secret_ssh_key = $config["Unsafe_SSH_private_key"]
    @public_ssh_key = $config["Unsafe_SSH_public_key"]
  else
    raise "Unknown server type #{server_type}"
  end

  @vm.execute_successfully("echo '#{@secret_ssh_key}' > '/home/#{LIVE_USER}/.ssh/id_rsa'", LIVE_USER)
  @vm.execute_successfully("echo '#{@public_ssh_key}' > '/home/#{LIVE_USER}/.ssh/id_rsa.pub'", LIVE_USER)
  @vm.execute_successfully("chmod 0600 '/home/#{LIVE_USER}/.ssh/'id*", LIVE_USER)
end

Given /^I verify the SSH fingerprint for the (Git repository|SSH server)$/ do |server_type|
  next if @skip_steps_while_restoring_background
  assert(server_type = 'Git repository' || server_type = 'SSH server',
         "Unknown server type #{server_type} specified.")
  @screen.wait("SSHFingerprint.png", 60)
  @screen.type('yes' + Sikuli::Key.ENTER)
end

When /^I connect to an SSH server on the Internet$/ do
  next if @skip_steps_while_restoring_background

  read_and_validate_ssh_config

  ssh_port_suffix = "-p #{@ssh_port}" if @ssh_port

  cmd = "ssh #{@ssh_username}@#{@ssh_host} #{ssh_port_suffix}"

  step 'process "ssh" is not running'
  step "I run \"#{cmd}\" in GNOME Terminal"
  step 'process "ssh" is running within 10 seconds'
end

Then /^I have sucessfully logged into the SSH server$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('SSHLoggedInPrompt.png', 60)
end

Then /^I connect to an SFTP server on the Internet$/ do
  next if @skip_steps_while_restoring_background

  read_and_validate_ssh_config

  @screen.wait_and_click("GnomePlaces.png", 20)
  @screen.wait_and_click("GnomePlacesConnectToServer.png", 20)
  @screen.wait("GnomeSSHConnect.png", 20)
  @screen.click("GnomeSSHFTP.png")
  @screen.click("GnomeSSHServerSSH.png")
  @screen.type(Sikuli::Key.TAB, Sikuli::KeyModifier.SHIFT) # port
  @screen.type(Sikuli::Key.TAB, Sikuli::KeyModifier.SHIFT) # host
  @screen.type(@ssh_host + Sikuli::Key.TAB)

  if @ssh_port
    @screen.type("#{@ssh_port}" + Sikuli::Key.TAB)
  else
    @screen.type("22" + Sikuli::Key.TAB)
  end
  @screen.type(Sikuli::Key.TAB) # type
  @screen.type(Sikuli::Key.TAB) # folder
  @screen.type(@ssh_username + Sikuli::Key.TAB)
  @screen.wait_and_click("GnomeSSHConnectButton.png", 60)
end

Then /^I verify the SSH fingerprint for the SFTP server$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("GnomeSSHVerificationConfirm.png", 60)
end

Then /^I successfully connect to the SFTP server$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("GnomeSSHSuccess.png", 60)
end
