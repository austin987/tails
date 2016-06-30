When /^I clone the Git repository "([\S]+)" in GNOME Terminal$/ do |repo|
  repo_directory = /[\S]+\/([\S]+)(\.git)?$/.match(repo)[1]
  assert(!$vm.directory_exist?("/home/#{LIVE_USER}/#{repo_directory}"))

  recovery_proc = Proc.new do
    if $vm.directory_exist?("/home/#{LIVE_USER}/#{repo_directory}")
      $vm.execute_successfully("rm -rf /home/#{LIVE_USER}/#{repo_directory}",
                               :user => LIVE_USER)
    end
    if $vm.has_process?("git")
      step 'I kill the process "git"'
    end
    @screen.type('clear' + Sikuli::Key.ENTER)
  end

  retry_tor(recovery_proc)  do
    step "I run \"git clone #{repo}\" in GNOME Terminal"
    m = /^(https?|git):\/\//.match(repo)
    unless m
      step 'I verify the SSH fingerprint for the Git repository'
    end
    @screen.wait('GitObjects.png', 40) # clone has actually started
  end
end

Then /^the Git repository "([\S]+)" has been cloned successfully$/ do |repo|
  assert($vm.directory_exist?("/home/#{LIVE_USER}/#{repo}/.git"))
  assert($vm.file_exist?("/home/#{LIVE_USER}/#{repo}/.git/config"))
  $vm.execute_successfully("cd '/home/#{LIVE_USER}/#{repo}/' && git status",
                           :user => LIVE_USER)
end
