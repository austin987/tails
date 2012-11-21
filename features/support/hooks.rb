require 'tmpdir'

Before do
  @orig_pwd = Dir.pwd
  @git_clone = Dir.mktmpdir 'tails-apt-tests'
  Dir.chdir @git_clone
end

After do
  Dir.chdir @orig_pwd
  FileUtils.remove_entry_secure @git_clone
end
