require 'rubygems'
require "#{Dir.pwd}/features/support/extra_hooks.rb"
require 'time'
require 'rspec'

def fatal_system(str)
  unless system(str)
    raise StandardError.new("Command exited with #{$?}")
  end
end

def git_exists?
  File.exists? '.git'
end

def create_git
  Dir.mkdir 'config'
  FileUtils.touch('config/base_branch')
  FileUtils.touch('config/APT_overlays')
  Dir.mkdir 'debian'
  File.open('debian/changelog', 'w') do |changelog|
    changelog.write(<<END_OF_CHANGELOG)
tails (0) stable; urgency=low

  * First release.

 -- Tails developers <tails@boum.org>  Mon, 30 Jan 2012 01:00:00 +0000
END_OF_CHANGELOG
  end

  fatal_system "git init --quiet"
  fatal_system "git config user.email 'tails@boum.org'"
  fatal_system "git config user.name 'Tails developers'"
  fatal_system "git add debian/changelog"
  fatal_system "git commit --quiet debian/changelog -m 'First release'"
  fatal_system "git branch -M stable"
  fatal_system "git branch testing stable"
  fatal_system "git branch devel stable"
  fatal_system "git branch feature/jessie devel"
end

def current_branch
  branch = `git branch | awk '/^\*/ { print $2 }'`.strip
  raise StandardError.new('git-branch failed.') if $? != 0

  return branch
end

RSpec::Matchers.define :have_suite do |suite|
  match do |string|
    # e.g.: `deb http://deb.tails.boum.org/ 0.10 main contrib non-free`
    %r{^deb +http://deb\.tails\.boum\.org/ +#{Regexp.escape(suite)} main}.match(string)
  end
  failure_message_for_should do |string|
    "expected the sources to include #{suite}\nCurrent sources : #{string}"
  end
  failure_message_for_should_not do |string|
    "expected the sources to exclude #{suite}\nCurrent sources : #{string}"
  end
  description do
    "expected an output with #{suite}"
  end
end
