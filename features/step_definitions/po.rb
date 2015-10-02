Given /^I am in the Git branch being tested$/ do
  Dir.chdir(GIT_DIR)
end

Then /^all the PO files should be correct$/ do
  File.exists?('./submodules/jenkins-tools/slaves/check_po')
  cmd_helper(['./submodules/jenkins-tools/slaves/check_po'])
end
