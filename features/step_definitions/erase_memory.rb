def udev_watchdog_monitored_device
  ps_output = $vm.execute_successfully('ps -wweo cmd').stdout
  udev_watchdog_cmd = '/usr/local/sbin/udev-watchdog'

  # The regex below looks for a line like the following:
  # /usr/local/sbin/udev-watchdog /devices/pci0000:00/0000:00:01.1/ata2/host1/target1:0:0/1:0:0:0/block/sr0 cd
  # We're only interested in the device itself, not in the type
  ps_output_scan = ps_output.scan(/^#{Regexp.escape(udev_watchdog_cmd)}\s(\S+)\s(?:cd|disk)$/)
  assert_equal(ps_output_scan.count, 1, "There should be one udev-watchdog running.")
  monitored_out = ps_output_scan.flatten[0]
  assert(!monitored_out.nil?)
  monitored_device_id = $vm.file_content('/sys' + monitored_out + '/dev').chomp
  monitored_device =
    $vm.execute_successfully(
      "readlink -f /dev/block/'#{monitored_device_id}'").stdout.chomp
  return monitored_device
end

Given /^udev-watchdog is monitoring the correct device$/ do
  assert_equal(udev_watchdog_monitored_device, boot_device)
end

Given /^the computer is a modern 64-bit system$/ do
  $vm.set_arch("x86_64")
  $vm.drop_hypervisor_feature("nonpae")
  $vm.add_hypervisor_feature("pae")
end

Given /^the computer is an old pentium without the PAE extension$/ do
  $vm.set_arch("i686")
  $vm.drop_hypervisor_feature("pae")
  # libvirt claim the following feature doesn't exit even though
  # it's listed in the hvm i686 capabilities...
#  $vm.add_hypervisor_feature("nonpae")
  # ... so we use a workaround until we can figure this one out.
  $vm.disable_pae_workaround
end

def which_kernel
  kernel_path = $vm.execute_successfully("tails-get-bootinfo kernel").stdout.chomp
  return File.basename(kernel_path)
end

Given /^the PAE kernel is running$/ do
  kernel = which_kernel
  assert_equal("vmlinuz2", kernel)
end

Given /^the non-PAE kernel is running$/ do
  kernel = which_kernel
  assert_equal("vmlinuz", kernel)
end

def used_ram_in_MiB
  return $vm.execute_successfully("free -m | awk '/^Mem:/ { print $3 }'").stdout.chomp.to_i
end

def detected_ram_in_MiB
  return $vm.execute_successfully("free -m | awk '/^Mem:/ { print $2 }'").stdout.chomp.to_i
end

Given /^at least (\d+) ([[:alpha:]]+) of RAM was detected$/ do |min_ram, unit|
  @detected_ram_m = detected_ram_in_MiB
  puts "Detected #{@detected_ram_m} MiB of RAM"
  min_ram_m = convert_to_MiB(min_ram.to_i, unit)
  # All RAM will not be reported by `free`, so we allow a 196 MB gap
  gap = convert_to_MiB(196, "MiB")
  assert(@detected_ram_m + gap >= min_ram_m, "Didn't detect enough RAM")
end

def pattern_coverage_in_guest_ram
  assert_not_nil(
    @free_mem_before_fill_b,
    "@free_mem_before_fill_b is not set, probably the required 'I fill the " +
    "guest's memory ...' step was not run")
  free_mem_before_fill_m = convert_to_MiB(@free_mem_before_fill_b, 'b')
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
  coverage = patterns_b.to_f/@free_mem_before_fill_b
  puts "Pattern coverage: #{"%.3f" % (coverage*100)}% (#{patterns_m} MiB " +
       "out of #{free_mem_before_fill_m} MiB initial free memory)"
  return coverage
end

Given /^I fill the guest's memory with a known pattern(| without verifying)$/ do |dont_verify|
  verify = dont_verify.empty?

  # Free some more memory by dropping the caches etc.
  $vm.execute_successfully("echo 3 > /proc/sys/vm/drop_caches")

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
  if verify
    coverage = pattern_coverage_in_guest_ram()
    min_coverage = 0.90
    assert(coverage > min_coverage,
           "#{"%.3f" % (coverage*100)}% of the free memory was filled with " +
           "the pattern, but more than #{"%.3f" % (min_coverage*100)}% was " +
           "expected")
  end
end

Then /^I find very few patterns in the guest's memory$/ do
  coverage = pattern_coverage_in_guest_ram()
  max_coverage = 0.005
  assert(coverage < max_coverage,
         "#{"%.3f" % (coverage*100)}% of the free memory still has the " +
         "pattern, but less than #{"%.3f" % (max_coverage*100)}% was expected")
end

Then /^I find many patterns in the guest's memory$/ do
  coverage = pattern_coverage_in_guest_ram()
  min_coverage = 0.9
  assert(coverage > min_coverage,
         "#{"%.3f" % (coverage*100)}% of the free memory still has the " +
         "pattern, but more than #{"%.3f" % (min_coverage*100)}% was expected")
end

When /^I reboot without wiping the memory$/ do
  $vm.reset
end

When /^I stop the boot at the bootloader menu$/ do
  @screen.wait(bootsplash, 90)
  @screen.wait(bootsplash_tab_msg, 10)
  @screen.type(Sikuli::Key.TAB)
  @screen.waitVanish(bootsplash_tab_msg, 1)
end

When /^I shutdown and wait for Tails to finish wiping the memory$/ do
  $vm.spawn("halt")
  nr_gibs_of_ram = convert_from_bytes($vm.get_ram_size_in_bytes, 'GiB').ceil
  try_for(nr_gibs_of_ram*5*60, { :msg => "memory wipe didn't finish, probably the VM crashed" }) do
    # We spam keypresses to prevent console blanking from hiding the
    # image we're waiting for
    @screen.type(" ")
    @screen.find('MemoryWipeCompleted.png')
  end
end
