require 'socket'

def assert_not_ipaddr(s)
  err_msg = "'#{s}' looks like a LAN IP address."
  assert_raise(IPAddr::InvalidAddressError, err_msg) do
    IPAddr.new(s)
  end
end

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
    assert_not_ipaddr(@ssh_host)
  when 'SFTP'
    @sftp_host       = conf["hostname"]
    @sftp_port       = conf["port"].to_i if conf["port"]
    @sftp_username   = conf["username"]
    assert_not_ipaddr(@sftp_host)
  end
end

Given /^I have the SSH key pair for an? (Git|SSH|SFTP) (?:repository|server)( on the LAN)?$/ do |server_type, lan|
  $vm.execute_successfully("install -m 0700 -d '/home/#{LIVE_USER}/.ssh/'",
                           :user => LIVE_USER)
  unless server_type == 'Git' || lan
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

Given /^I (?:am prompted to )?verify the SSH fingerprint for the (?:Git|SSH) (?:repository|server)$/ do
  @screen.wait("SSHFingerprint.png", 60)
  sleep 1 # brief pause to ensure that the following keystrokes do not get lost
  @screen.type('yes' + Sikuli::Key.ENTER)
end

def get_free_tcp_port
  server = TCPServer.new('127.0.0.1', 0)
  return server.addr[1]
ensure
  server.close
end

Given /^an SSH server is running on the LAN$/ do
  @sshd_server_port = get_free_tcp_port
  @sshd_server_host = $vmnet.bridge_ip_addr
  sshd = SSHServer.new(@sshd_server_host, @sshd_server_port)
  sshd.start
  add_extra_allowed_host(@sshd_server_host, @sshd_server_port)
  add_after_scenario_hook { sshd.stop }
end

When /^I connect to an SSH server on the (Internet|LAN)$/ do |location|

  case location
  when 'Internet'
    read_and_validate_ssh_config "SSH"
  when 'LAN'
    @ssh_port = @sshd_server_port
    @ssh_username = 'user'
    @ssh_host = @sshd_server_host
  end

  ssh_port_suffix = "-p #{@ssh_port}" if @ssh_port

  cmd = "ssh #{@ssh_username}@#{@ssh_host} #{ssh_port_suffix}"

  step 'process "ssh" is not running'

  recovery_proc = Proc.new do
    step 'I kill the process "ssh"' if $vm.has_process?("ssh")
    step 'I run "clear" in GNOME Terminal'
  end

  retry_tor(recovery_proc) do
    step "I run \"#{cmd}\" in GNOME Terminal"
    step 'process "ssh" is running within 10 seconds'
    step 'I verify the SSH fingerprint for the SSH server'
  end
end

Then /^I have sucessfully logged into the SSH server$/ do
  @screen.wait('SSHLoggedInPrompt.png', 60)
end

Then /^I connect to an SFTP server on the Internet$/ do
  read_and_validate_ssh_config "SFTP"

  @sftp_port ||= 22
  @sftp_port = @sftp_port.to_s

  recovery_proc = Proc.new do
    step 'I kill the process "ssh"'
    step 'I kill the process "nautilus"'
  end

  retry_tor(recovery_proc) do
    step 'I start "Nautilus" via GNOME Activities Overview'
    nautilus = Dogtail::Application.new('nautilus')
    nautilus.child(roleName: 'frame')
    nautilus.child('Other Locations', roleName: 'label').click
    connect_bar = nautilus.child('Connect to Server', roleName: 'label').parent
    connect_bar
      .child(roleName: 'filler', recursive: false)
      .child(roleName: 'text', recursive: false)
      .text = "sftp://" + @sftp_username + "@" + @sftp_host + ":" + @sftp_port
    connect_bar.button('Connect', recursive: false).click
    step "I verify the SSH fingerprint for the SFTP server"
  end
end

Then /^I verify the SSH fingerprint for the SFTP server$/ do
  try_for(30) do
    Dogtail::Application.new('gnome-shell').child?('Log In Anyway')
  end
  # Here we'd like to click on the button using Dogtail, but something
  # is buggy so let's just use the keyboard.
  @screen.type(Sikuli::Key.TAB)
  @screen.type(Sikuli::Key.ENTER)
end

Then /^I successfully connect to the SFTP server$/ do
  try_for(60) do
    Dogtail::Application.new('nautilus')
      .child?("#{@sftp_username} on #{@sftp_host}")
  end
end
