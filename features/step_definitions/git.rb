Then /^the Git repository "([\S]+)" has been cloned successfully$/ do |repo|
  next if @skip_steps_while_restoring_background
  assert(@vm.directory_exist?("/home/#{$live_user}/#{repo}/.git"))
  assert(@vm.file_exist?("/home/#{$live_user}/#{repo}/.git/config"))
  @vm.execute_successfully("cd '/home/#{$live_user}/#{repo}/' && git status", $live_user)
end

Given /^I have the SSH key pair for a Git repository$/ do
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("install -m 0700 -d '/home/#{$live_user}/.ssh/'", $live_user)
  assert(!$tails_test_secret_ssh_key.nil? && $tails_test_secret_ssh_key.length > 0)
  assert(!$tails_test_public_ssh_key.nil? && $tails_test_public_ssh_key.length > 0)
  @vm.execute_successfully("echo '#{$tails_test_secret_ssh_key}' > '/home/#{$live_user}/.ssh/id_rsa'", $live_user)
  @vm.execute_successfully("echo '#{$tails_test_public_ssh_key}' > '/home/#{$live_user}/.ssh/id_rsa.pub'", $live_user)
  @vm.execute_successfully("chmod 0600 '/home/#{$live_user}/.ssh/'id*", $live_user)
end

Given /^I verify the SSH fingerprint for the Git repository$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("GitSSHFingerprint.png", 60)
  @screen.type('yes' + Sikuli::Key.ENTER)
end
