When /^I set the system time to "([^"]+)"$/ do |time|
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("date -s '#{time}'")
  new_time = DateTime.parse(@vm.execute_successfully("date").stdout).to_time
  # Allow 1 seconds delays.
  expected_time_lower_bound = DateTime.parse(time).to_time
  expected_time_upper_bound = expected_time_lower_bound + 1
  assert(expected_time_lower_bound >= new_time &&
                    new_time <= expected_time_upper_bound,
         "The guest's time was supposed to be set to " \
         "'#{expected_time_lower_bound}' but is '#{new_time}'")
end

When /^I bump the system time with "([^"]+)"$/ do |timediff|
  next if @skip_steps_while_restoring_background
  old_time = DateTime.parse(@vm.execute_successfully("date").stdout).to_time
  @vm.execute_successfully("date -s 'now #{timediff}'")
  new_time = DateTime.parse(@vm.execute_successfully("date").stdout).to_time
  # Allow 1 seconds delays.
  expected_time_lower_bound = DateTime.parse(
      cmd_helper("date -d '#{old_time} #{timediff}'")).to_time
  expected_time_upper_bound = expected_time_lower_bound + 1
  assert(expected_time_lower_bound >= new_time &&
                    new_time <= expected_time_upper_bound,
         "The guest's time was supposed to be bumped to " \
         "'#{expected_time_lower_bound}' but is '#{new_time}'")
end

Then /^Tails clock is less than (\d+) minutes incorrect$/ do |max_diff_mins|
  next if @skip_steps_while_restoring_background
  guest_time_str = @vm.execute("date --rfc-2822").stdout.chomp
  guest_time = Time.rfc2822(guest_time_str)
  host_time = Time.now
  diff = (host_time - guest_time).abs
  assert(diff < max_diff_mins.to_i*60,
         "The guest's clock is off by #{diff} seconds (#{guest_time})")
  puts "Time was #{diff} seconds off"
end
