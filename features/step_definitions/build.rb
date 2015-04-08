Given /^Tails ([[:alnum:].]+) has been released$/ do |version|
  create_git unless git_exists?

  old_branch = current_branch

  fatal_system "git checkout --quiet stable"
  old_entries = File.open('debian/changelog') { |f| f.read }
  File.open('debian/changelog', 'w') do |changelog|
    changelog.write(<<END_OF_CHANGELOG)
tails (#{version}) stable; urgency=low

  * New upstream release.

 -- Tails developers <tails@boum.org>  Tue, 31 Jan 2012 15:12:57 +0100

#{old_entries}
END_OF_CHANGELOG
  end
  fatal_system "git commit --quiet debian/changelog -m 'Release #{version}'"
  fatal_system "git tag '#{version}'"

  if old_branch != 'stable'
    fatal_system "git checkout --quiet '#{old_branch}'"
    fatal_system "git merge    --quiet 'stable'"
  end
end

Given /^Tails ([[:alnum:].-]+) has been tagged$/ do |version|
  fatal_system "git tag '#{version}'"
end

Given /^Tails ([[:alnum:].]+) has not been released yet$/ do |version|
  !File.exists? ".git/refs/tags/#{version}"
end

Given /^the last version mentioned in debian\/changelog is ([[:alnum:]~.]+)$/ do |version|
  last = `dpkg-parsechangelog | awk '/^Version: / { print $2 }'`.strip
  raise StandardError.new('dpkg-parsechangelog failed.') if $? != 0

  if last != version
    fatal_system "debchange -v '#{version}' 'New upstream release'"
  end
end

Given %r{I am working on the ([[:alnum:]./_-]+) base branch$} do |branch|
  create_git unless git_exists?

  if current_branch != branch
    fatal_system "git checkout --quiet '#{branch}'"
  end

  File.open('config/base_branch', 'w+') do |base_branch_file|
    base_branch_file.write("#{branch}\n")
  end
end

Given %r{I am working on the ([[:alnum:]./_-]+) branch based on ([[:alnum:]./_-]+)$} do |branch, base|
  create_git unless git_exists?

  if current_branch != branch
    fatal_system "git checkout --quiet -b '#{branch}' '#{base}'"
  end

  File.open('config/base_branch', 'w+') do |base_branch_file|
    base_branch_file.write("#{base}\n")
  end
end

When /^I successfully run ([[:alnum:]-]+)$/ do |command|
  @output = `#{File.expand_path("../../../auto/scripts/#{command}", __FILE__)}`
  raise StandardError.new("#{command} failed. Exit code: #{$?}") if $? != 0
end

When /^I run ([[:alnum:]-]+)$/ do |command|
  @output = `#{File.expand_path("../../../auto/scripts/#{command}", __FILE__)}`
  @exit_code = $?
end

Then /^I should see the ['"]?([[:alnum:].-]+)['"]? suite$/ do |suite|
  @output.should have_suite(suite)
end

Then /^I should see only the ['"]?([[:alnum:].-]+)['"]? suite$/ do |suite|
  assert_equal(1, @output.lines.count)
  @output.should have_suite(suite)
end

Then /^I should not see the ['"]?([[:alnum:].-]+)['"]? suite$/ do |suite|
  @output.should_not have_suite(suite)
end

Given(/^the config\/APT_overlays\.d directory is empty$/) do
  Dir.glob('config/APT_overlays.d/*').empty? \
  or raise "config/APT_overlays.d/ is not empty"
end

Given(/^config\/APT_overlays\.d contains ['"]?([[:alnum:].-]+)['"]?$/) do |suite|
  FileUtils.touch("config/APT_overlays.d/#{suite}")
end

Then(/^it should fail$/) do
  assert_not_equal(0, @exit_code)
end

Given(/^the (config\/base_branch) file does not exist$/) do |file|
  File.delete(file)
end

Given(/^the (config\/APT_overlays\.d) directory does not exist$/) do |dir|
  Dir.rmdir(dir)
end

Given(/^the config\/base_branch file is empty$/) do
  File.open('config/base_branch', 'w+') { }
end
