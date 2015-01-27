Given /^I create an? ([[:alnum:]]+) partition( labeled "([^"]+)")? with an? ([[:alnum:]]+) filesystem( encrypted with password "([^"]+)")? on disk "([^"]+)"$/ do |parttype, has_label, label, fstype, is_encrypted, luks_password, name|
  next if @skip_steps_while_restoring_background
  opts = {}
  opts.merge!(:label => label) if has_label
  opts.merge!(:luks_password => luks_password) if is_encrypted
  @vm.storage.disk_mkpartfs(name, parttype, fstype, opts)
end

Given /^I cat an ISO hybrid of the Tails image to disk "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  tails_iso_hybrid = "#{$tmp_dir}/#{File.basename($tails_iso)}"
  begin
    cmd_helper("cp '#{$tails_iso}' '#{tails_iso_hybrid}'")
    cmd_helper("isohybrid '#{tails_iso_hybrid}' --entry 4 --type 0x1c")
    src_disk = {
      :path => tails_iso_hybrid,
      :opts => {
        :format => "raw",
        :readonly => true
      }
    }
    dest_disk = {
      :path => @vm.storage.disk_path(name),
      :opts => {
        :format => @vm.storage.disk_format(name)
      }
    }
    @vm.storage.guestfs_disk_helper(src_disk, dest_disk) do |g, src_disk_handle, dest_disk_handle|
      g.copy_device_to_device(src_disk_handle, dest_disk_handle, {})
    end
  ensure
    cmd_helper("rm -f '#{tails_iso_hybrid}'")
  end
end

Then /^drive "([^"]+)" is not mounted$/ do |name|
  next if @skip_steps_while_restoring_background
  dev = @vm.disk_dev(name)
  assert(!@vm.execute("grep -qs '^#{dev}' /proc/mounts").success?,
         "an untrusted partition from drive '#{name}' was automounted")
end

Then /^Tails Greeter has( not)? detected a persistence partition$/ do |no_persistence|
  next if @skip_steps_while_restoring_background
  expecting_persistence = no_persistence.nil?
  @screen.find('TailsGreeter.png')
  found_persistence = ! @screen.exists('TailsGreeterPersistence.png').nil?
  assert_equal(expecting_persistence, found_persistence,
               "Persistence is unexpectedly#{no_persistence} enabled")
end
