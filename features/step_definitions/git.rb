Then /^the Git repository "([\S]+)" has been cloned successfully$/ do |repo|
  assert($vm.directory_exist?("/home/#{LIVE_USER}/#{repo}/.git"))
  assert($vm.file_exist?("/home/#{LIVE_USER}/#{repo}/.git/config"))
  $vm.execute_successfully("cd '/home/#{LIVE_USER}/#{repo}/' && git status",
                           :user => LIVE_USER)
end
