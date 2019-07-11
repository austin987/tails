When /^I clone the Git repository "([\S]+)" in GNOME Terminal$/ do |repo|
  repo_directory = /[\S]+\/([\S]+)(\.git)?$/.match(repo)[1]
  assert(!$vm.directory_exist?("/home/#{LIVE_USER}/#{repo_directory}"))

  recovery_proc = Proc.new do
    $vm.execute("rm -rf /home/#{LIVE_USER}/#{repo_directory}",
                             :user => LIVE_USER)
    step 'I kill the process "git"'
    @screen.type('clear' + Sikuli::Key.ENTER)
  end

  retry_tor(recovery_proc) do
    step "I run \"git clone #{repo}\" in GNOME Terminal"
    m = /^(https?|git):\/\//.match(repo)
    unless m
      step 'I verify the SSH fingerprint for the Git repository'
    end
    try_for(180, :msg => 'Git process took too long') {
      !$vm.has_process?('/usr/bin/git')
    }
    Dogtail::Application.new('gnome-terminal-server')
      .child('Terminal', roleName: 'terminal')
      .text['Unpacking objects: 100%']
  end
end

Then /^the Git repository "([\S]+)" has been cloned successfully$/ do |repo|
  assert($vm.directory_exist?("/home/#{LIVE_USER}/#{repo}/.git"))
  assert($vm.file_exist?("/home/#{LIVE_USER}/#{repo}/.git/config"))
  $vm.execute_successfully("cd '/home/#{LIVE_USER}/#{repo}/' && git status",
                           :user => LIVE_USER)
end
