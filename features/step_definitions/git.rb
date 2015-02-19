Then /^the Git repository "([\S]+)" has been cloned successfully$/ do |repo|
  next if @skip_steps_while_restoring_background
  assert(@vm.directory_exist?("/home/#{LIVE_USER}/#{repo}/.git"))
  assert(@vm.file_exist?("/home/#{LIVE_USER}/#{repo}/.git/config"))
  @vm.execute_successfully("cd '/home/#{LIVE_USER}/#{repo}/' && git status", LIVE_USER)
end

Given /^I have the SSH key pair for a Git repository$/ do
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("install -m 0700 -d '/home/#{LIVE_USER}/.ssh/'", LIVE_USER)
  secret_ssh_key = $config["Unsafe_SSH_private_key"]
  public_ssh_key = $config["Unsafe_SSH_public_key"]
  assert(!secret_ssh_key.nil? && secret_ssh_key.length > 0)
  assert(!public_ssh_key.nil? && public_ssh_key.length > 0)
  @vm.execute_successfully("echo '#{secret_ssh_key}' > '/home/#{LIVE_USER}/.ssh/id_rsa'", LIVE_USER)
  @vm.execute_successfully("echo '#{public_ssh_key}' > '/home/#{LIVE_USER}/.ssh/id_rsa.pub'", LIVE_USER)
  @vm.execute_successfully("chmod 0600 '/home/#{LIVE_USER}/.ssh/'id*", LIVE_USER)
end

Given /^I verify the SSH fingerprint for the Git repository$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("GitSSHFingerprint.png", 60)
  @screen.type('yes' + Sikuli::Key.ENTER)
end
