When /^I clone the Git repository "([\S]+)" in GNOME Terminal$/ do |repo|
  repo_directory = %r{[\S]+/([\S]+)(\.git)?$}.match(repo)[1]
  assert(!$vm.directory_exist?("/home/#{LIVE_USER}/#{repo_directory}"))

  recovery_proc = proc do
    $vm.execute("rm -rf /home/#{LIVE_USER}/#{repo_directory}",
                user: LIVE_USER)
    step 'I kill the process "git"'
    @screen.type('clear')
    @screen.press('Return')
  end

  retry_tor(recovery_proc) do
    step "I run \"git clone #{repo}\" in GNOME Terminal"
    m = %r{^(https?|git)://}.match(repo)
    step 'I verify the SSH fingerprint for the Git repository' unless m
    try_for(180, msg: 'Git process took too long') do
      !$vm.process_running?('/usr/bin/git')
    end
    Dogtail::Application.new('gnome-terminal-server')
                        .child('Terminal', roleName: 'terminal')
                        .text['Unpacking objects: 100%']
  end
end

Then /^the Git repository "([\S]+)" has been cloned successfully$/ do |repo|
  assert($vm.directory_exist?("/home/#{LIVE_USER}/#{repo}/.git"))
  assert($vm.file_exist?("/home/#{LIVE_USER}/#{repo}/.git/config"))
  $vm.execute_successfully("cd '/home/#{LIVE_USER}/#{repo}/' && git status",
                           user: LIVE_USER)
end
