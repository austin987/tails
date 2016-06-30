When /^I give Git (\d+) seconds to clone "([\S]+)"$/ do |time_to_wait, repo|
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

  retry_tor(recovery_proc) do
    step "I run \"git clone #{repo}\" in GNOME Terminal"
    m = /^(https?|git):\/\//.match(repo)
    unless m
      step 'I verify the SSH fingerprint for the Git repository'
    end
    try_for(time_to_wait.to_i, :msg => 'Git process took too long') {
      !$vm.has_process?('/usr/bin/git')
    }
    @screen.wait('GitCloneDone.png', 10)
  end
end

Then /^the Git repository "([\S]+)" has been cloned successfully$/ do |repo|
  assert($vm.directory_exist?("/home/#{LIVE_USER}/#{repo}/.git"))
  assert($vm.file_exist?("/home/#{LIVE_USER}/#{repo}/.git/config"))
  $vm.execute_successfully("cd '/home/#{LIVE_USER}/#{repo}/' && git status",
                           :user => LIVE_USER)
end
