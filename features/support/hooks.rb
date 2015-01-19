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
  Dir.glob("#{$config["TMP_DIR"]}/*.state").each do |snapshot|
    delete_snapshot(snapshot)
  end
end

BeforeFeature('@product') do |feature|
  if File.exist?($config["TMP_DIR"])
    if !File.directory?($config["TMP_DIR"])
      raise "Temporary directory '#{$config["TMP_DIR"]}' exists but is not a " +
            "directory"
    end
    if !File.owned?($config["TMP_DIR"])
      raise "Temporary directory '#{$config["TMP_DIR"]}' must be owned by the " +
            "current user"
    end
    FileUtils.chmod(0755, $config["TMP_DIR"])
  else
    begin
      Dir.mkdir($config["TMP_DIR"])
    rescue Errno::EACCES => e
      raise "Cannot create temporary directory: #{e.to_s}"
    end
  end
  delete_all_snapshots if !$keep_snapshots
  if $tails_iso.nil?
    raise "No Tails ISO image specified, and none could be found in the " +
          "current directory"
  end
  if File.exist?($tails_iso)
    # Workaround: when libvirt takes ownership of the ISO image it may
    # become unreadable for the live user inside the guest in the
    # host-to-guest share used for some tests.

    if !File.world_readable?($tails_iso)
      if File.owned?($tails_iso)
        File.chmod(0644, $tails_iso)
      else
        raise "warning: the Tails ISO image must be world readable or be " +
              "owned by the current user to be available inside the guest " +
              "VM via host-to-guest shares, which is required by some tests"
      end
    end
  else
    raise "The specified Tails ISO image '#{$tails_iso}' does not exist"
  end
  puts "Testing ISO image: #{File.basename($tails_iso)}"
  base = File.basename(feature.file, ".feature").to_s
  $background_snapshot = "#{$config["TMP_DIR"]}/#{base}_background.state"
end

AfterFeature('@product') do
  delete_snapshot($background_snapshot) if !$keep_snapshots
  VM.storage.clear_volumes if VM.storage
end

BeforeFeature('@product', '@old_iso') do
  if $old_tails_iso.nil?
    raise "No old Tails ISO image specified, and none could be found in the " +
          "current directory"
  end
  if !File.exist?($old_tails_iso)
    raise "The specified old Tails ISO image '#{$old_tails_iso}' does not exist"
  end
  if $tails_iso == $old_tails_iso
    raise "The old Tails ISO is the same as the Tails ISO we're testing"
  end
  puts "Using old ISO image: #{File.basename($old_tails_iso)}"
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
  @os_loader = "MBR"
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
    tmp = @screen.capture.getFilename
    out = "#{$config["TMP_DIR"]}/#{base}-#{DateTime.now}.png"
    FileUtils.mv(tmp, out)
    STDERR.puts("Took screenshot \"#{out}\"")
    if $config["PAUSE_ON_FAIL"]
      STDERR.puts ""
      STDERR.puts "Press ENTER to continue running the test suite"
      STDIN.gets
    end
  end
  if @sniffer
    @sniffer.stop
    @sniffer.clear
  end
  @vm.destroy if @vm
end

After('@product', '~@keep_volumes') do
  VM.storage.clear_volumes
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
  FileUtils.remove_entry_secure @git_clone
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
