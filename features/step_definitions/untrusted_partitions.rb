Given /^I create an? ([[:alnum:]]+) swap partition on disk "([^"]+)"$/ do |parttype, name|
  $vm.storage.disk_mkswap(name, parttype)
end

Then /^an? "([^"]+)" partition was detected by Tails on drive "([^"]+)"$/ do |type, name|
  part_info = $vm.execute_successfully(
      "blkid '#{$vm.disk_dev(name)}'").stdout.strip
  assert(part_info.split.grep(/^TYPE=\"#{Regexp.escape(type)}\"$/),
         "No #{type} partition was detected by Tails on disk '#{name}'")
end

Then /^Tails has no disk swap enabled$/ do
  # Skip first line which contain column headers
  swap_info = $vm.execute_successfully("tail -n+2 /proc/swaps").stdout
  assert(swap_info.empty?,
         "Disk swapping is enabled according to /proc/swaps:\n" + swap_info)
  mem_info = $vm.execute_successfully("grep '^Swap' /proc/meminfo").stdout
  assert(mem_info.match(/^SwapTotal:\s+0 kB$/),
             "Disk swapping is enabled according to /proc/meminfo:\n" +
             mem_info)
end

Given /^I create an?( (\d+) ([[:alpha:]]+))? ([[:alnum:]]+) partition( labeled "([^"]+)")? with an? ([[:alnum:]]+) filesystem( encrypted with password "([^"]+)")? on disk "([^"]+)"$/ do |with_size, size, unit, parttype, has_label, label, fstype, is_encrypted, luks_password, name|
  opts = {}
  opts.merge!(:label => label) if has_label
  opts.merge!(:luks_password => luks_password) if is_encrypted
  opts.merge!(:size => size) if with_size
  opts.merge!(:unit => unit) if with_size
  $vm.storage.disk_mkpartfs(name, parttype, fstype, opts)
end

Given /^I write (|an old version of )the Tails (ISO|USB) image to disk "([^"]+)"$/ do |old, type, name|
  src_disk = {
    :path => (old == '' ? (type == 'ISO' ? TAILS_ISO : TAILS_IMG)
                        : (type == 'ISO' ? OLD_TAILS_ISO : OLD_TAILS_IMG)),
    :opts => {
      :format => "raw",
      :readonly => true
    }
  }
  dest_disk = {
    :path => $vm.storage.disk_path(name),
    :opts => {
      :format => $vm.storage.disk_format(name)
    }
  }
  $vm.storage.guestfs_disk_helper(src_disk, dest_disk) do |g, src_disk_handle, dest_disk_handle|
    g.copy_device_to_device(src_disk_handle, dest_disk_handle, {})
  end
end

Then /^drive "([^"]+)" is not mounted$/ do |name|
  dev = $vm.disk_dev(name)
  assert(!$vm.execute("grep -qs '^#{dev}' /proc/mounts").success?,
         "an untrusted partition from drive '#{name}' was automounted")
end

Then /^Tails Greeter has( not)? detected a persistence partition$/ do |no_persistence|
  expecting_persistence = no_persistence.nil?
  @screen.find('TailsGreeter.png')
  found_persistence = ! @screen.exists('TailsGreeterPersistencePassphrase.png').nil?
  assert_equal(expecting_persistence, found_persistence,
               "Persistence is unexpectedly#{no_persistence} enabled")
end
