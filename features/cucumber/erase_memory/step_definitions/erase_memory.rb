Given /^I fill the guest's memory with a known pattern$/ do
  next if @skip_steps_while_restoring_background
  # To be sure that we fill all memory we run one fillram instance
  # for each GiB of memory, rounded up. We also kill all instances
  # after the first one has finished, i.e. when the memory is full,
  # since the others otherwise may continue re-filling the same memory
  # unnecessarily.
  instances = (@vm.get_ram_size_in_bytes.to_f/(2**30)).ceil
  instances.times { @vm.spawn('/usr/local/sbin/fillram; killall fillram') }
  # We make sure that the filling has started...
  try_for(10, { :msg => "fillram didn't start" }) {
    @vm.execute("pgrep fillram").success?
  }
  # ... and that it finishes
  try_for(instances*60, { :msg => "fillram didn't complete, probably the VM crashed" }) {
    ! @vm.execute("pgrep fillram").success?
  }
end

When /^I dump the guest's memory into file "([^"]+)"$/ do |dump|
  dump_path = "#{$tmp_dir}/#{dump}"
  @vm.domain.core_dump(dump_path)
end

Then /^I find at least (\d+) patterns in the dump "([^"]+)"$/ do |min, dump|
  dump_path = "#{$tmp_dir}/#{dump}"
  hits = IO.popen("grep -c 'wipe_didnt_work' #{dump_path}").gets
  puts "Patterns found: #{hits}"
  File.delete dump_path
  assert(hits.to_i >= min.to_i, "Too few patterns found, see #{dump_path}")
end

Then /^I find at most (\d+) patterns in the dump "([^"]+)"$/ do |max, dump|
  dump_path = "#{$tmp_dir}/#{dump}"
  hits = IO.popen("grep -c 'wipe_didnt_work' #{dump_path}").gets
  puts "Patterns found: #{hits}"
  File.delete dump_path
  assert(hits.to_i <= max.to_i, "Too many patterns found, see #{dump_path}")
end

When /^I shutdown Tails and let it wipe the memory$/ do
  next if @skip_steps_while_restoring_background
  @vm.execute("halt")
  @screen.wait('MemoryWipeCompleted.png', 120)
end
