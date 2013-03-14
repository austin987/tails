Given /^the computer is a modern 64-bit system$/ do
  next if @skip_steps_while_restoring_background
  @vm.set_arch("x86_64")
  @vm.drop_hypervisor_feature("nonpae")
  @vm.add_hypervisor_feature("pae")
end

Given /^the computer is an old pentium without the PAE extension$/ do
  next if @skip_steps_while_restoring_background
  @vm.set_arch("i686")
  @vm.drop_hypervisor_feature("pae")
  # libvirt claim the following feature doesn't exit even though
  # it's listed in the hvm i686 capabilities...
#  @vm.add_hypervisor_feature("nonpae")
  # ... so we use a workaround until we can figure this one out.
  @vm.disable_pae_workaround
end

def kernel_check(expected_kernel)
  kernel_path = @vm.execute("/usr/local/bin/tails-get-bootinfo kernel").stdout.chomp
  kernel = File.basename(kernel_path)
  assert(kernel == expected_kernel,
         "Kernel #{kernel} is running, expected #{expected_kernel}")
end

Given /^the PAE kernel is running$/ do
  next if @skip_steps_while_restoring_background
  kernel_check("vmlinuz2")
end

Given /^the non-PAE kernel is running$/ do
  next if @skip_steps_while_restoring_background
  kernel_check("vmlinuz")
end

def detected_ram_in_bytes
  return @vm.execute("free -b | awk '/^Mem:/ { print $2 }'").stdout.chomp.to_i
end

Given /^at least (\d+) ([[:alpha:]]+) of RAM was detected$/ do |min_ram, unit|
  @detected_ram_b = detected_ram_in_bytes
  next if @skip_steps_while_restoring_background
  puts "Detected #{@detected_ram_b} bytes of RAM"
  min_ram_b = convert_to_bytes(min_ram.to_i, unit)
  # All RAM will not be reported by `free`, so we allow a 128 MB gap
  gap = convert_to_bytes(128, "MiB")
  assert(@detected_ram_b + gap >= min_ram_b, "Didn't detect enough RAM")
end

def pattern_coverage_in_guest_ram
  dump = "#{$tmp_dir}/memdump"
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
  @vm.domain.core_dump(dump)
  patterns = IO.popen("grep -c 'wipe_didnt_work' #{dump}").gets.to_i
  File.delete dump
  # Pattern is 16 bytes long
  patterns_b = patterns*16
  coverage = patterns_b.to_f/@detected_ram_b.to_f
  puts "Pattern coverage: #{"%.3f" % (coverage*100)}% (#{patterns_b} bytes)"
  return coverage
end

Given /^I fill the guest's memory with a known pattern$/ do
  next if @skip_steps_while_restoring_background
  # To be sure that we fill all memory we run one fillram instance
  # for each GiB of detected memory, rounded up. We also kill all instances
  # after the first one has finished, i.e. when the memory is full,
  # since the others otherwise may continue re-filling the same memory
  # unnecessarily.
  instances = (@detected_ram_b.to_f/(2**30)).ceil
  instances.times { @vm.spawn('/usr/local/sbin/fillram; killall fillram') }
  # We make sure that the filling has started...
  try_for(10, { :msg => "fillram didn't start" }) {
    @vm.execute("pgrep fillram").success?
  }
  # ... and that it finishes
  try_for(instances*60, { :msg => "fillram didn't complete, probably the VM crashed" }) {
    ! @vm.execute("pgrep fillram").success?
  }
  coverage = pattern_coverage_in_guest_ram()
  min_coverage = 0.9
  assert(coverage > min_coverage,
         "#{"%.3f" % (coverage*100)}% of the memory is filled with the " +
         "pattern, but more than #{"%.3f" % (min_coverage*100)}% was expected")
end

Then /^I find very few patterns in the guest's memory$/ do
  coverage = pattern_coverage_in_guest_ram()
  max_coverage = 0.001
  assert(coverage < max_coverage,
         "#{"%.3f" % (coverage*100)}% of the memory is filled with the " +
         "pattern, but less than #{"%.3f" % (max_coverage*100)}% was expected")
end

When /^I shutdown Tails and let it wipe the memory$/ do
  next if @skip_steps_while_restoring_background
  @vm.execute("halt")
  @screen.wait('MemoryWipeCompleted.png', 120)
end
