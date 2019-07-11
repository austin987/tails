def udev_watchdog_monitored_device
  ps_output = $vm.execute_successfully('ps -wweo cmd').stdout
  udev_watchdog_cmd = '/usr/local/sbin/udev-watchdog'

  # The regex below looks for a line like the following:
  # /usr/local/sbin/udev-watchdog /devices/pci0000:00/0000:00:01.1/ata2/host1/target1:0:0/1:0:0:0/block/sr0 cd
  # We're only interested in the device itself, not in the type
  ps_output_scan = ps_output.scan(/^#{Regexp.escape(udev_watchdog_cmd)}\s(\S+)\s(?:cd|disk)$/)
  assert_equal(ps_output_scan.count, 1, "There should be one udev-watchdog running.")
  monitored_out = ps_output_scan.flatten[0]
  assert_not_nil(monitored_out)
  monitored_device_id = $vm.file_content('/sys' + monitored_out + '/dev').chomp
  monitored_device =
    $vm.execute_successfully(
      "readlink -f /dev/block/'#{monitored_device_id}'").stdout.chomp
  return monitored_device
end

Given /^udev-watchdog is monitoring the correct device$/ do
  assert_equal(udev_watchdog_monitored_device, boot_device)
end

def used_ram_in_MiB
  return $vm.execute_successfully("free -m | awk '/^Mem:/ { print $3 }'").stdout.chomp.to_i
end

def detected_ram_in_MiB
  return $vm.execute_successfully("free -m | awk '/^Mem:/ { print $2 }'").stdout.chomp.to_i
end

def pattern_coverage_in_guest_ram(reference_memory_b)
  assert_not_nil(reference_memory_b)
  reference_memory_m = convert_to_MiB(reference_memory_b, 'b')
  dump = "#{$config["TMPDIR"]}/memdump"
  # Workaround: when dumping the guest's memory via core_dump(), libvirt
  # will create files that only root can read. We therefore pre-create
  # them with more permissible permissions, which libvirt will preserve
  # (although it will change ownership) so that the user running the
  # script can grep the dump for the fillram pattern, and delete it.
  if File.exist?(dump)
    File.delete(dump)
  end
  FileUtils.touch(dump)
  FileUtils.chmod(0666, dump)
  $vm.domain.core_dump(dump)
  patterns = IO.popen(['grep', '--text', '-c', 'wipe_didnt_work', dump]).gets.to_i
  File.delete dump
  # Pattern is 16 bytes long
  patterns_b = patterns*16
  patterns_m = convert_to_MiB(patterns_b, 'b')
  coverage = patterns_b.to_f/reference_memory_b
  puts "Pattern coverage: #{"%.3f" % (coverage*100)}% (#{patterns_m} MiB " +
       "out of #{reference_memory_m} MiB reference memory)"
  return coverage
end

Given /^I prepare Tails for memory erasure tests$/ do
  @detected_ram_m = detected_ram_in_MiB

  # Free some more memory by dropping the caches etc.
  step "I drop all kernel caches"

  # Have our initramfs-pre-shutdown-hook sleep for a while
  $vm.execute_successfully("touch /run/initramfs/tails_shutdown_debugging")

  # The (guest) kernel may freeze when approaching full memory without
  # adjusting the OOM killer and memory overcommitment limitations.
  kernel_mem_reserved_k = 64*1024
  kernel_mem_reserved_m = convert_to_MiB(kernel_mem_reserved_k, 'k')
  admin_mem_reserved_k = 128*1024
  admin_mem_reserved_m = convert_to_MiB(admin_mem_reserved_k, 'k')
  kernel_mem_settings = [
    # Let's avoid killing other random processes, and instead focus on
    # the hoggers, which will be our fillram instances.
    ["vm.oom_kill_allocating_task", 0],
    # Let's not print stuff to the terminal.
    ["vm.oom_dump_tasks", 0],
    # From tests the 'guess' heuristic seems to allow us to safely
    # (i.e. no kernel freezes) fill the maximum amount of RAM.
    ["vm.overcommit_memory", 0],
    # Make sure the kernel doesn't starve...
    ["vm.min_free_kbytes", kernel_mem_reserved_k],
    # ... and also some core privileged processes, e.g. the remote
    # shell.
    ["vm.admin_reserve_kbytes", admin_mem_reserved_k],
  ]
  kernel_mem_settings.each do |key, val|
    $vm.execute_successfully("sysctl #{key}=#{val}")
  end

  # We exclude the memory we reserve for the kernel and admin
  # processes above from the free memory since fillram will be run by
  # an unprivileged user in user-space.
  used_mem_before_fill_m = used_ram_in_MiB
  free_mem_before_fill_m = @detected_ram_m - used_mem_before_fill_m -
                          kernel_mem_reserved_m - admin_mem_reserved_m
  @free_mem_before_fill_b = convert_to_bytes(free_mem_before_fill_m, 'MiB')

  ['initramfs-shutdown', 'memlockd', 'tails-shutdown-on-media-removal'].each do |srv|
    assert($vm.execute("systemctl status #{srv}.service").success?)
  end
end

Given /^I fill the guest's memory with a known pattern and the allocating processes get killed$/ do
  # To be sure that we fill all memory we run one fillram instance for
  # each GiB of detected memory, rounded up. To maintain stability we
  # prioritize the fillram instances to be OOM killed. We also kill
  # all instances after the first one has finished, i.e. when the
  # memory is full, since the others otherwise may continue re-filling
  # the same memory unnecessarily. Note that we leave the `killall`
  # call outside of the OOM adjusted shell so it will not be OOM
  # killed too.
  nr_instances = (@detected_ram_m.to_f/(2**10)).ceil
  nr_instances.times do
    oom_adjusted_fillram_cmd =
      "echo 1000 > /proc/$$/oom_score_adj && exec /usr/local/sbin/fillram"
    $vm.spawn("sh -c '#{oom_adjusted_fillram_cmd}'; killall fillram",
              :user => LIVE_USER)
  end
  # We make sure that all fillram processes have started...
  try_for(10, :msg => "all fillram processes didn't start", :delay => 0.1) do
    nr_fillram_procs = $vm.pidof("fillram").size
    nr_instances == nr_fillram_procs
  end
  prev_used_ram_ratio = -1
  # ... and that it finishes
  try_for(nr_instances*2*60, { :msg => "fillram didn't complete, probably the VM crashed" }) do
    used_ram_ratio = (used_ram_in_MiB.to_f/@detected_ram_m)*100
    # Round down to closest multiple of 10 to limit the logging a bit.
    used_ram_ratio = (used_ram_ratio/10).round*10
    if used_ram_ratio - prev_used_ram_ratio >= 10
      debug_log("Memory fill progress: %3d%%" % used_ram_ratio)
      prev_used_ram_ratio = used_ram_ratio
    end
    ! $vm.has_process?("fillram")
  end
  debug_log("Memory fill progress: finished")
end

def avail_space_in_mountpoint_kB(mountpoint)
  return $vm.execute_successfully(
    "df --output=avail '#{mountpoint}'"
  ).stdout.split("\n")[1].to_i
end

def assert_filesystem_is_full(mountpoint)
  avail_space = avail_space_in_mountpoint_kB(mountpoint)
  assert_equal(
    0, avail_space,
    "#{avail_space} kB is still free on #{mountpoint}," +
    "while this filesystem was expected to be full"
  )
end

When /^I mount a (\d+) MiB tmpfs on "([^"]+)" and fill it with a known pattern$/ do |size_MiB, mountpoint|
  size_MiB = size_MiB.to_i
  @tmp_filesystem_size_b = convert_to_bytes(size_MiB, 'MiB')
  $vm.execute_successfully(
    "mount -t tmpfs -o 'size=#{size_MiB}M' tmpfs '#{mountpoint}'"
  )
  $vm.execute_successfully(
    "while echo wipe_didnt_work >> '#{mountpoint}/file'; do true ; done"
   )
  assert_filesystem_is_full(mountpoint)
end

When(/^I fill the USB drive with a known pattern$/) do
  $vm.execute_successfully(
    "while echo wipe_didnt_work >> '#{@tmp_usb_drive_mount_dir}/file'; do true ; done"
   )
  assert_filesystem_is_full(@tmp_usb_drive_mount_dir)
end

When(/^I read the content of the test FS$/) do
  $vm.execute_successfully("cat #{@tmp_usb_drive_mount_dir}/file >/dev/null")
end

Then /^patterns cover at least (\d+)% of the test FS size in the guest's memory$/ do |expected_coverage|
  reference_memory_b = @tmp_filesystem_size_b
  tmp_filesystem_size_MiB = convert_from_bytes(@tmp_filesystem_size_b, 'MiB')
  coverage = pattern_coverage_in_guest_ram(reference_memory_b)
  min_coverage = expected_coverage.to_f / 100
  assert(coverage > min_coverage,
         "#{"%.3f" % (coverage*100)}% of the test FS size (#{tmp_filesystem_size_MiB} MiB) " +
         "has the pattern, but more than #{"%.3f" % (min_coverage*100)}% " +
         "was expected")
end

Then(/^patterns cover at least (\d+) MiB in the guest's memory$/) do |expected_patterns_MiB|
  reference_memory_b = convert_to_bytes(expected_patterns_MiB.to_i, 'MiB')
  coverage = pattern_coverage_in_guest_ram(reference_memory_b)
  min_coverage = 1
  assert(coverage >= min_coverage,
         "#{"%.3f" % (coverage*100)}% of the expected size (#{expected_patterns_MiB} MiB) " +
         "has the pattern, but more than #{"%.3f" % (min_coverage*100)}% " +
         "was expected")
end

Then(/^patterns cover less than (\d+) MiB in the guest's memory$/) do |expected_patterns_MiB|
  reference_memory_b = convert_to_bytes(expected_patterns_MiB.to_i, 'MiB')
  coverage = pattern_coverage_in_guest_ram(reference_memory_b)
  max_coverage = 1
  assert(coverage < max_coverage,
         "#{"%.3f" % (coverage*100)}% of the expected size (#{expected_patterns_MiB} MiB) " +
         "has the pattern, but less than #{"%.3f" % (max_coverage*100)}% " +
         "was expected")
end

When(/^I umount "([^"]*)"$/) do |mount_arg|
  $vm.execute_successfully("umount '#{mount_arg}'")
end

Then /^I find very few patterns in the guest's memory$/ do
  coverage = pattern_coverage_in_guest_ram(@free_mem_before_fill_b)
  max_coverage = 0.008
  assert(coverage < max_coverage,
         "#{"%.3f" % (coverage*100)}% of the free memory still has the " +
         "pattern, but less than #{"%.3f" % (max_coverage*100)}% was expected")
end

When /^I stop the boot at the bootloader menu$/ do
  step "Tails is at the boot menu's cmdline"
end

When /^I wait for Tails to finish wiping the memory$/ do
  @screen.wait("MemoryWipeCompleted.png", 90)
end

When(/^I fill a (\d+) MiB file with a known pattern on the (persistent|root) filesystem$/) do |size_MiB, fs|
  pattern = "wipe_didnt_work\n"
  pattern_nb = (convert_to_bytes(size_MiB.to_i, 'MiB') / pattern.size).floor
  if fs == 'root'
    dest_file = "/" + random_alpha_string(10)
  elsif fs == 'persistent'
    dest_file = "/home/amnesia/Persistent/" + random_alpha_string(10)
  else
    raise "This should not happen"
  end
  $vm.execute_successfully(
    "for i in $(seq 1 #{pattern_nb}) ; do " +
    "   echo wipe_didnt_work >> '#{dest_file}' ; " +
    "done"
   )
end

When(/^I drop all kernel caches$/) do
  $vm.execute_successfully("echo 3 > /proc/sys/vm/drop_caches")
end

When(/^I trigger shutdown$/) do
  $vm.spawn("halt")
end
