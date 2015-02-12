Then /^the Git repository "([\S]+)" has been cloned successfully$/ do |repo|
  next if @skip_steps_while_restoring_background
  assert(@vm.directory_exist?("/home/#{$live_user}/#{repo}/.git"))
  assert(@vm.file_exist?("/home/#{$live_user}/#{repo}/.git/config"))
  @vm.execute_successfully("cd '/home/#{$live_user}/#{repo}/' && git status", $live_user)
end
