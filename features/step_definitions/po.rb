Given /^I am in the Git branch being tested$/ do
  File.exists?("$git_dir/wiki/src/contribute/l10n_tricks/check_po.sh")
end

Given /^all the PO files should be correct$/ do
  Dir.chdir($git_dir)
  cmd_helper('./wiki/src/contribute/l10n_tricks/check_po.sh')
end
