Given /^I have the SSH key pair for an? (Git repository|SSH server)(?: on the| on a)?\s*(|LAN|Internet)$/ do |server_type, loc|
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("install -m 0700 -d '/home/#{LIVE_USER}/.ssh/'", LIVE_USER)
  case server_type
  when "SSH server"
    prefix = ''
  when "Git repository"
    prefix = "Unsafe_"
  else
    raise "Unknown server type #{server_type}"
  end

  case loc
  when 'Internet', ''
    location = '_'
  when 'LAN'
    location = '_LAN_'
  else
    raise "Unknown location #{loc} specified."
  end
  secret_ssh_key = $config[prefix + "SSH#{location}private_key"]
  public_ssh_key = $config[prefix + "SSH#{location}public_key"]
  assert(!secret_ssh_key.nil? && secret_ssh_key.length > 0, "no key in SSH#{location}private_key ?")
  assert(!public_ssh_key.nil? && public_ssh_key.length > 0, "no key in SH#{location}public_key ?")
  @vm.execute_successfully("echo '#{secret_ssh_key}' > '/home/#{LIVE_USER}/.ssh/id_rsa'", LIVE_USER)
  @vm.execute_successfully("echo '#{public_ssh_key}' > '/home/#{LIVE_USER}/.ssh/id_rsa.pub'", LIVE_USER)
  @vm.execute_successfully("chmod 0600 '/home/#{LIVE_USER}/.ssh/'id*", LIVE_USER)
end

Given /^I verify the SSH fingerprint for the (Git repository|SSH server)$/ do |server_type|
  next if @skip_steps_while_restoring_background
  assert(server_type = 'Git repository' || server_type = 'SSH server',
         "Unknown server type #{server_type} specified.")
  @screen.wait("SSHFingerprint.png", 60)
  @screen.type('yes' + Sikuli::Key.ENTER)
end
