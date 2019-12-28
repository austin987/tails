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
  # Make sure to close after reading stdout, to avoid Zombies:
  grep = IO.popen(['grep', '--text', '-c', 'wipe_didnt_work', dump])
  patterns = grep.gets.to_i
  grep.close
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
  # Have our initramfs-pre-shutdown-hook sleep for a while
  $vm.execute_successfully("touch /run/initramfs/tails_shutdown_debugging")

  # We exclude the memory we reserve for the kernel and admin
  # processes above from the free memory since fillram will be run by
  # an unprivileged user in user-space.
  detected_ram_m = detected_ram_in_MiB
  used_mem_before_fill_m = used_ram_in_MiB
  free_mem_before_fill_m = detected_ram_m - used_mem_before_fill_m
  @free_mem_before_fill_b = convert_to_bytes(free_mem_before_fill_m, 'MiB')

  ['initramfs-shutdown', 'memlockd', 'tails-shutdown-on-media-removal'].each do |srv|
    assert($vm.execute("systemctl status #{srv}.service").success?)
  end
end

When /^I start a process allocating (\d+) ([[:alpha:]]+) of memory with a known pattern$/ do |size, unit|
  fillram_script_path = "/tmp/fillram"
  @fillram_cmd = "python3 #{fillram_script_path}"
  fillram_done_path = fillram_script_path + "_done"
  fillram_script = <<-EOF
import math
import time
pattern = "wipe_didnt_work\\n"
buffer = ""
for x in range(math.ceil(#{convert_to_bytes(size.to_i, unit)} / len(pattern))):
  buffer += pattern
with open("#{fillram_done_path}", "w") as f:
  f.write("done")
time.sleep(365*24*60*60)
print(buffer)
  EOF
  $vm.file_overwrite(fillram_script_path, fillram_script)
  $vm.spawn(@fillram_cmd)
  try_for(60) { $vm.file_exist?(fillram_done_path) }
end

When /^I kill the allocating process$/ do
  $vm.execute_successfully("pkill --full '^#{@fillram_cmd}'")
  try_for(10) do
    $vm.execute("pgrep --full '^#{@fillram_cmd}'").failure?
  end
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
