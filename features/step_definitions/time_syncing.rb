When /^I set the system time to "([^"]+)"$/ do |time|
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("date -s '#{time}'")
end

When /^I bump the system time with "([^"]+)"$/ do |timediff|
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("date -s 'now #{timediff}'")
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
