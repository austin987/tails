Given /^Tails ([[:alnum:].]+) has been released$/ do |version|
  create_git unless git_exists?

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
end

Given /^Tails ([[:alnum:].-]+) has been tagged$/ do |version|
  fatal_system "git tag '#{version}'"
end

Given /^Tails ([[:alnum:].]+) has not been released yet$/ do |version|
  !File.exists? ".git/refs/tags/#{version}"
end

Given /^last released version mentioned in debian\/changelog is ([[:alnum:]~.]+)$/ do |version|
  last = `dpkg-parsechangelog | awk '/^Version: / { print $2 }'`.strip
  raise StandardError.new('dpkg-parsechangelog failed.') if $? != 0

  if last != version
    fatal_system "debchange -v '#{version}' 'New upstream release'"
  end
end

Given %r{I am working on the ([[:alnum:]./_-]+) branch$} do |branch|
  create_git unless git_exists?

  current_branch = `git branch | awk '/^\*/ { print $2 }'`.strip
  raise StandardError.new('git-branch failed.') if $? != 0

  if current_branch != branch
    fatal_system "git checkout --quiet '#{branch}'"
  end
end

Given %r{I am working on the ([[:alnum:]./_-]+) branch based on ([[:alnum:]./_-]+)$} do |branch, base|
  create_git unless git_exists?

  current_branch = `git branch | awk '/^\*/ { print $2 }'`.strip
  raise StandardError.new('git-branch failed.') if $? != 0

  if current_branch != branch
    fatal_system "git checkout --quiet -b '#{branch}' '#{base}'"
  end
end

When /^I run ([[:alnum:]-]+)$/ do |command|
  @output = `#{File.expand_path("../../../auto/scripts/#{command}", __FILE__)}`
  raise StandardError.new("#{command} failed. Exit code: #{$?}") if $? != 0
end

Then /^I should see the ['"]?([[:alnum:].-]+)['"]? suite$/ do |suite|
  @output.should have_suite(suite)
end

Then /^I should not see ['"]?([[:alnum:].-]+)['"]? suite$/ do |suite|
  @output.should_not have_suite(suite)
end
