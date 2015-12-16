def read_and_validate_ssh_config srv_type
  conf  = $config[srv_type]
  begin
    required_settings = ["private_key", "public_key", "username", "hostname"]
    required_settings.each do |key|
      assert(conf.has_key?(key))
      assert_not_nil(conf[key])
      assert(!conf[key].empty?)
    end
  rescue NoMethodError
    raise(
      <<EOF
Your #{srv_type} config is incorrect or missing from your local configuration file (#{LOCAL_CONFIG_FILE}). See wiki/src/contribute/release_process/test/usage.mdwn for the format.
EOF
    )
  end

  case srv_type
  when 'SSH'
    @ssh_host        = conf["hostname"]
    @ssh_port        = conf["port"].to_i if conf["port"]
    @ssh_username    = conf["username"]
    assert(!@ssh_host.match(/^(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))/), "#{@ssh_host} " +
           "looks like a LAN IP address.")

  when 'SFTP'
    @sftp_host       = conf["hostname"]
    @sftp_port       = conf["port"].to_i if conf["port"]
    @sftp_username   = conf["username"]

    assert(!@sftp_host.match(/^(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))/), "#{@sftp_host} " +
           "looks like a LAN IP address.")
  end
end

Given /^I have the SSH key pair for an? (Git|SSH|SFTP) (?:repository|server)$/ do |server_type|
  $vm.execute_successfully("install -m 0700 -d '/home/#{LIVE_USER}/.ssh/'",
                           :user => LIVE_USER)
  unless server_type == 'Git'
    read_and_validate_ssh_config server_type
    secret_key = $config[server_type]["private_key"]
    public_key = $config[server_type]["public_key"]
  else
    secret_key = $config["Unsafe_SSH_private_key"]
    public_key = $config["Unsafe_SSH_public_key"]
  end

  $vm.execute_successfully("echo '#{secret_key}' > '/home/#{LIVE_USER}/.ssh/id_rsa'",
                           :user => LIVE_USER)
  $vm.execute_successfully("echo '#{public_key}' > '/home/#{LIVE_USER}/.ssh/id_rsa.pub'",
                           :user => LIVE_USER)
  $vm.execute_successfully("chmod 0600 '/home/#{LIVE_USER}/.ssh/'id*",
                           :user => LIVE_USER)
end

Given /^I verify the SSH fingerprint for the (?:Git|SSH) (?:repository|server)$/ do
  @screen.wait("SSHFingerprint.png", 60)
  @screen.type('yes' + Sikuli::Key.ENTER)
end

When /^I connect to an SSH server on the Internet$/ do

  read_and_validate_ssh_config "SSH"

  ssh_port_suffix = "-p #{@ssh_port}" if @ssh_port

  cmd = "ssh #{@ssh_username}@#{@ssh_host} #{ssh_port_suffix}"

  step 'process "ssh" is not running'
  step "I run \"#{cmd}\" in GNOME Terminal"
  step 'process "ssh" is running within 10 seconds'
end

Then /^I have sucessfully logged into the SSH server$/ do
  @screen.wait('SSHLoggedInPrompt.png', 60)
end

Then /^I connect to an SFTP server on the Internet$/ do
  read_and_validate_ssh_config "SFTP"
  @sftp_port ||= 22
  @sftp_port = @sftp_port.to_s
  step 'I start "Files" via the GNOME "Accessories" applications menu'
  @screen.wait_and_click("GnomeFilesConnectToServer.png", 10)
  @screen.wait("GnomeConnectToServerWindow.png", 10)
  @screen.type("sftp://" + @sftp_username + "@" + @sftp_host + ":" + @sftp_port)
  @screen.wait_and_click("GnomeConnectToServerConnectButton.png", 10)
end

Then /^I verify the SSH fingerprint for the SFTP server$/ do
  @screen.wait_and_click("GnomeSSHVerificationConfirm.png", 60)
end

Then /^I successfully connect to the SFTP server$/ do
  @screen.wait("GnomeSSHSuccess.png", 60)
end
