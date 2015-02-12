Then /^the Git repository "([\S]+)" has been cloned successfully$/ do |repo|
  next if @skip_steps_while_restoring_background
  assert(@vm.directory_exist?("/home/#{$live_user}/#{repo}/.git"))
  assert(@vm.file_exist?("/home/#{$live_user}/#{repo}/.git/config"))
  @vm.execute_successfully("cd '/home/#{$live_user}/#{repo}/' && git status", $live_user)
end

Given /^I have the SSH key for a Git repository$/ do
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("install -m 0700 -d /home/#{$live_user}/.ssh/", $live_user)
  secret_key=ENV['TAILS_TEST_SECRET_KEY']
  public_key=ENV['TAILS_TEST_PUBLIC_KEY']
  assert(!secret_key.nil? && secret_key.length > 0)
  assert(!public_key.nil? && public_key.length > 0)
  @vm.execute_successfully("echo '#{secret_key}' > /home/#{$live_user}/.ssh/id_rsa", $live_user)
  @vm.execute_successfully("echo '#{public_key}' > /home/#{$live_user}/.ssh/id_rsa.pub", $live_user)
  @vm.execute_successfully("chmod 600 /home/#{$live_user}/.ssh/id*", $live_user)
end

Given /^I verify the SSH fingerprint for the Git repository$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("GitSSHFingerprint.png", 60)
  @screen.type('yes' + Sikuli::Key.ENTER)
end
