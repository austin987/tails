require 'fileutils'
require 'time'
require 'tmpdir'

# For @product tests
####################

def delete_snapshot(snapshot)
  if snapshot and File.exist?(snapshot)
    File.delete(snapshot)
  end
rescue Errno::EACCES => e
  STDERR.puts "Couldn't delete background snapshot: #{e.to_s}"
end

def delete_all_snapshots
  Dir.glob("#{$tmp_dir}/*.state").each do |snapshot|
    delete_snapshot(snapshot)
  end
end

BeforeFeature('@product') do |feature|
  $tmp_dir = ENV['TEMP_DIR'] || "/tmp/TailsToaster"
  if File.exist?($tmp_dir)
    if !File.directory?($tmp_dir)
      raise "Temporary directory '#{$tmp_dir}' exists but is not a " +
            "directory"
    end
    if !File.owned?($tmp_dir)
      raise "Temporary directory '#{$tmp_dir}' must be owned by the " +
            "current user"
    end
    FileUtils.chmod(0755, $tmp_dir)
  else
    begin
      Dir.mkdir($tmp_dir)
    rescue Errno::EACCES => e
      raise "Cannot create temporary directory: #{e.to_s}"
    end
  end
  $vm_xml_path = ENV['VM_XML_PATH'] || "#{Dir.pwd}/features/domains"
  $misc_files_dir = "#{Dir.pwd}/features/misc_files"
  $keep_snapshots = !ENV['KEEP_SNAPSHOTS'].nil?
  delete_all_snapshots if !$keep_snapshots
  $tails_iso = ENV['ISO'] || get_last_iso
  if $tails_iso.nil?
    raise "No Tails ISO image specified, and none could be found in the " +
          "current directory"
  end
  if File.exist?($tails_iso)
    # Workaround: when libvirt takes ownership of the ISO image it may
    # become unreadable for the live user inside the guest in the
    # host-to-guest share used for some tests.

    # jruby 1.5.6 doesn't have world_readable? in File or File::Stat so we
    # manually check for it in the mode string
    if !(File.stat($tails_iso).mode & 04)
      if File.owned?($tails_iso)
        chmod(0644, $tails_iso)
      else
        raise "warning: the Tails ISO image must be world readable or be " +
              "owned by the current user to be available inside the guest " +
              "VM via host-to-guest shares, which is required by some tests"
      end
    end
  else
    raise "The specified Tails ISO image '#{$tails_iso}' does not exist"
  end
  $x_display = ENV['DISPLAY']
  $live_user = "amnesia"
  base = File.basename(feature.file, ".feature").to_s
  $background_snapshot = "#{$tmp_dir}/#{base}_background.state"
end

AfterFeature('@product') do
  delete_snapshot($background_snapshot) if !$keep_snapshots
  VM.storage.clear_volumes if VM.storage
end

# BeforeScenario
Before('@product') do
  @screen = Sikuli::Screen.new
  if File.size?($background_snapshot)
    @skip_steps_while_restoring_background = true
  else
    @skip_steps_while_restoring_background = false
  end
  @theme = "gnome"
end

# AfterScenario
After('@product') do |scenario|
  if (scenario.status != :passed)
    time_of_fail = Time.now - $time_at_start
    secs = "%02d" % (time_of_fail % 60)
    mins = "%02d" % ((time_of_fail / 60) % 60)
    hrs  = "%02d" % (time_of_fail / (60*60))
    STDERR.puts "Scenario failed at time #{hrs}:#{mins}:#{secs}"
    base = File.basename(scenario.feature.file, ".feature").to_s
    @vm.take_screenshot("#{base}-#{DateTime.now}") if @vm
  end
  if @sniffer
    @sniffer.stop
    @sniffer.clear
  end
  @vm.destroy if @vm
end


# For @source tests
###################

# BeforeScenario
Before('@source') do
  @orig_pwd = Dir.pwd
  @git_clone = Dir.mktmpdir 'tails-apt-tests'
  Dir.chdir @git_clone
end

# AfterScenario
After('@source') do
  Dir.chdir @orig_pwd
  # Seems like JRuby has issues with remove_entry_secure()
  FileUtils.remove_entry @git_clone
end


# Common
########

BeforeFeature('@product', '@source') do |feature|
  raise "Feature #{feature.file} is tagged both @product and @source, " +
        "which is an impossible combination"
end

at_exit do
  delete_all_snapshots if !$keep_snapshots
  VM.storage.clear_pool if VM.storage
end
