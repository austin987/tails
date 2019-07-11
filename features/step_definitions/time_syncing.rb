# In some steps below we allow some slack when verifying that the date
# was set appropriately because it may take time to send the `date`
# command over the remote shell and get the answer back, parsing and
# post-processing of the result, etc.
def max_time_drift
  15
end

When /^I set the system time to "([^"]+)"$/ do |time|
  $vm.execute_successfully("date -s '#{time}'")
  new_time = DateTime.parse($vm.execute_successfully("date").stdout).to_time
  expected_time_lower_bound = DateTime.parse(time).to_time
  expected_time_upper_bound = expected_time_lower_bound + max_time_drift
  assert(expected_time_lower_bound <= new_time &&
         new_time <= expected_time_upper_bound,
         "The guest's time was supposed to be set to " \
         "'#{expected_time_lower_bound}' but is '#{new_time}'")
end

When /^I bump the (hardware clock's|system) time with "([^"]+)"$/ do |clock_type, timediff|
  case clock_type
  when "hardware clock's"
    old_time = DateTime.parse($vm.execute_successfully("hwclock -r").stdout).to_time
    $vm.execute_successfully("hwclock --set --date 'now #{timediff}'")
    new_time = DateTime.parse($vm.execute_successfully("hwclock -r").stdout).to_time
  when 'system'
    old_time = DateTime.parse($vm.execute_successfully("date").stdout).to_time
    $vm.execute_successfully("date -s 'now #{timediff}'")
    new_time = DateTime.parse($vm.execute_successfully("date").stdout).to_time
  end
  expected_time_lower_bound = DateTime.parse(
      cmd_helper(["date", "-d", "#{old_time} #{timediff}"])).to_time
  expected_time_upper_bound = expected_time_lower_bound + max_time_drift
  assert(expected_time_lower_bound <= new_time &&
         new_time <= expected_time_upper_bound,
         "The #{clock_type} time was supposed to be bumped to " \
         "'#{expected_time_lower_bound}' but is '#{new_time}'")
end

Then /^Tails clock is less than (\d+) minutes incorrect$/ do |max_diff_mins|
  guest_time_str = $vm.execute("date --rfc-2822").stdout.chomp
  guest_time = Time.rfc2822(guest_time_str)
  host_time = Time.now
  diff = (host_time - guest_time).abs
  assert(diff < max_diff_mins.to_i*60,
         "The guest's clock is off by #{diff} seconds (#{guest_time})")
  puts "Time was #{diff} seconds off"
end

Then /^the system clock is just past Tails' source date$/ do
  system_time_str = $vm.execute_successfully('date').to_s
  system_time = DateTime.parse(system_time_str).to_time
  source_time_cmd = 'sed -n -e "1s/^.* - \([0-9]\+\)$/\1/p;q" ' +
                    '/etc/amnesia/version'
  source_time_str = $vm.execute_successfully(source_time_cmd).to_s
  source_time = DateTime.parse(source_time_str).to_time
  diff = system_time - source_time  # => in seconds
  # Half an hour should be enough to boot Tails on any reasonable
  # hardware and VM setup.
  max_diff = 30*60
  assert(diff > 0,
         "The system time (#{system_time}) is before the Tails " +
         "source date (#{source_time})")

  if diff <= max_diff
    # In this case the only acceptable explanation is that systemd
    # adjusted the time.
    systemd_has_adjusted_time = $vm.execute(
      "journalctl | grep 'System time before build time, advancing clock'"
    ).success?
    if ! systemd_has_adjusted_time
      raise(
        "The system time (#{system_time}) is more than #{max_diff} seconds " +
        "past the source date (#{source_time}) and systemd was not involved"
      )
    end
  end
end

Then /^Tails' hardware clock is close to the host system's time$/ do
  host_time = Time.now
  hwclock_time_str = $vm.execute('hwclock -r').stdout.chomp
  hwclock_time = DateTime.parse(hwclock_time_str).to_time
  diff = (hwclock_time - host_time).abs
  assert(diff <= max_time_drift)
end

Then /^the hardware clock is still off by "([^"]+)"$/ do |timediff|
  hwclock = DateTime.parse($vm.execute_successfully("hwclock -r").stdout.chomp).to_time
  expected_time_lower_bound = DateTime.parse(
      cmd_helper(["date", "-d", "now #{timediff}"])).to_time - max_time_drift
  expected_time_upper_bound = expected_time_lower_bound + max_time_drift
  assert(expected_time_lower_bound <= hwclock &&
         hwclock <= expected_time_upper_bound,
         "The host's hwclock should be approximately " \
         "'#{expected_time_lower_bound}' but is actually '#{hwclock}'")
end
