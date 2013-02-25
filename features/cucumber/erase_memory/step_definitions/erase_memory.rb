Given /^I fill the guest's memory with a known pattern$/ do
  #@vm.execute("for i in $(seq 1 16); do /usr/local/sbin/fillram & done")
  @vm.execute("/usr/local/sbin/fillram")
end

When /^I dump the guest's memory into file "([^"]+)"$/ do |dump|
  dump_path = "#{Dir.pwd}/features/tmpfs/#{dump}"
  @vm.domain.core_dump(dump_path)
end

Then /^I find at least (\d+) patterns in the dump "([^"]+)"$/ do |min, dump|
  dump_path = "#{Dir.pwd}/features/tmpfs/#{dump}"
  hits = IO.popen("grep -c 'wipe_didnt_work' #{dump_path}").gets
  puts "Patterns found: #{hits}"
  assert(hits.to_i >= min.to_i, "Too few patterns found")
end

Then /^I find at most (\d+) patterns in the dump "([^"]+)"$/ do |max, dump|
  dump_path = "#{Dir.pwd}/features/tmpfs/#{dump}"
  hits = IO.popen("grep -c 'wipe_didnt_work' #{dump_path}").gets
  puts "Patterns found: #{hits}"
  assert(hits.to_i <= max.to_i, "Too many patterns found")
end

When /^I shutdown Tails and let it wipe the memory$/ do
  next if @skip_steps_while_restoring_background
  assert @vm.execute("halt").success?
  @screen.wait('MemoryWipeCompleted.png', 120)
end
