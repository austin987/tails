Given /^I create a (\d+) ([[:alpha:]]+) disk named "([^"]+)"$/ do |size, unit, name|
  next if @skip_steps_while_restoring_background
  @vm.storage.create_new_disk(name, {:size => size, :unit => unit,
                                     :type => "raw"})
end

Given /^I create a ([[:alpha:]]+) label on disk "([^"]+)"$/ do |type, name|
  next if @skip_steps_while_restoring_background
  @vm.storage.disk_mklabel(name, type)
end

Given /^I create a ([[:alnum:]]+) filesystem on disk "([^"]+)"$/ do |type, name|
  next if @skip_steps_while_restoring_background
  @vm.storage.disk_mkpartfs(name, type)
end

Given /^I cat an ISO of the Tails image to disk "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  disk_path = @vm.storage.disk_path(name)
  cmd_helper("dd if='#{tails_iso}' of='#{disk_path}' conv=notrunc")
end

Then /^drive "([^"]+)" is not mounted$/ do |name|
  next if @skip_steps_while_restoring_background
  dev = @vm.disk_dev(name)
  assert(!@vm.execute("grep -qs '^#{dev}' /proc/mounts").success?,
         "an untrusted partition from drive '#{name}' was automounted")
end
