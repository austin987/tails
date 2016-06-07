Given /^Tails ([[:alnum:]~.]+) has been released$/ do |version|
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
  fatal_system "git tag '#{version.gsub('~', '-')}'"

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

Given /^the last versions mentioned in debian\/changelog are ([[:alnum:]~.]+) and ([[:alnum:]~.]+)$/ do |version_a, version_b|
  step "the last version mentioned in debian/changelog is #{version_a}"
  step "the last version mentioned in debian/changelog is #{version_b}"
end

Given(/^no frozen APT snapshot is encoded in config\/APT_snapshots\.d$/) do
  ['debian', 'debian-security', 'torproject'].map do |origin|
    File.open("config/APT_snapshots.d/#{origin}/serial", 'w+') do |serial|
      serial.write("latest\n")
    end
  end
end

Given(/^frozen APT snapshots are encoded in config\/APT_snapshots\.d$/) do
  ['debian', 'torproject'].map do |origin|
    File.open("config/APT_snapshots.d/#{origin}/serial", 'w+') do |serial|
      serial.write("2016060602\n")
    end
  end
  # We never freeze debian-security
  File.open("config/APT_snapshots.d/debian-security/serial", 'w+') do |serial|
    serial.write("latest\n")
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

Given %r{^I checkout the ([[:alnum:]~.-]+) tag$} do |tag|
  create_git unless git_exists?
  fatal_system "git checkout --quiet #{tag}"
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

When /^I successfully run "?([[:alnum:] -]+)"?$/ do |command|
  @output = `#{File.expand_path("../../../auto/scripts/#{command}", __FILE__)}`
  raise StandardError.new("#{command} failed. Exit code: #{$?}") if $? != 0
end

When /^I run "?([[:alnum:] -]+)"?$/ do |command|
  @output = `#{File.expand_path("../../../auto/scripts/#{command}", __FILE__)}`
  @exit_code = $?.exitstatus
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
  File.truncate('config/base_branch', 0)
end

Then(/^I should see the ([[:alnum:].-]+) tagged snapshot$/) do |tag|
  @output.should have_tagged_snapshot(tag)
end

Then(/^I should see a time\-based snapshot$/) do
  @output.should have_time_based_snapshot()
end
