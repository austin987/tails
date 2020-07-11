Then /^all the PO files should be correct$/ do
  File.exist?('./submodules/jenkins-tools/slaves/check_po')
  cmd_helper(['./submodules/jenkins-tools/slaves/check_po'])
end
