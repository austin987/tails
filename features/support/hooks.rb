require 'fileutils'
require 'rb-inotify'
require 'time'
require 'tmpdir'

# Run once, before any feature
AfterConfiguration do |config|
  if File.exist?($config["TMPDIR"])
    if !File.directory?($config["TMPDIR"])
      raise "Temporary directory '#{$config["TMPDIR"]}' exists but is not a " +
            "directory"
    end
    if !File.owned?($config["TMPDIR"])
      raise "Temporary directory '#{$config["TMPDIR"]}' must be owned by the " +
            "current user"
    end
    FileUtils.chmod(0755, $config["TMPDIR"])
  else
    begin
      FileUtils.mkdir_p($config["TMPDIR"])
    rescue Errno::EACCES => e
      raise "Cannot create temporary directory: #{e.to_s}"
    end
  end
  # Start a thread that monitors a pseudo fifo file and debug_log():s
  # anything written to it "immediately" (well, as fast as inotify
  # detects it). We're forced to a convoluted solution like this
  # because CRuby's thread support is horribly as soon as IO is mixed
  # in (other threads get blocked).
  FileUtils.rm(DEBUG_LOG_PSEUDO_FIFO) if File.exist?(DEBUG_LOG_PSEUDO_FIFO)
  FileUtils.touch(DEBUG_LOG_PSEUDO_FIFO)
  at_exit do
    FileUtils.rm(DEBUG_LOG_PSEUDO_FIFO) if File.exist?(DEBUG_LOG_PSEUDO_FIFO)
  end
  Thread.new do
    File.open(DEBUG_LOG_PSEUDO_FIFO) do |fd|
      watcher = INotify::Notifier.new
      watcher.watch(DEBUG_LOG_PSEUDO_FIFO, :modify) do
        line = fd.read.chomp
        debug_log(line) if line and line.length > 0
      end
      watcher.run
    end
  end
  # Fix Sikuli's debug_log():ing.
  bind_java_to_pseudo_fifo_logger
end

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
  Dir.glob("#{$config["TMPDIR"]}/*.state").each do |snapshot|
    delete_snapshot(snapshot)
  end
end

def add_after_scenario_hook(&block)
  @after_scenario_hooks ||= Array.new
  @after_scenario_hooks << block
end

BeforeFeature('@product') do |feature|
  delete_all_snapshots if !KEEP_SNAPSHOTS
  if TAILS_ISO.nil?
    raise "No Tails ISO image specified, and none could be found in the " +
          "current directory"
  end
  if File.exist?(TAILS_ISO)
    # Workaround: when libvirt takes ownership of the ISO image it may
    # become unreadable for the live user inside the guest in the
    # host-to-guest share used for some tests.

    if !File.world_readable?(TAILS_ISO)
      if File.owned?(TAILS_ISO)
        File.chmod(0644, TAILS_ISO)
      else
        raise "warning: the Tails ISO image must be world readable or be " +
              "owned by the current user to be available inside the guest " +
              "VM via host-to-guest shares, which is required by some tests"
      end
    end
  else
    raise "The specified Tails ISO image '#{TAILS_ISO}' does not exist"
  end
  puts "Testing ISO image: #{File.basename(TAILS_ISO)}"
  if !File.exist?(OLD_TAILS_ISO)
    raise "The specified old Tails ISO image '#{OLD_TAILS_ISO}' does not exist"
  end
  puts "Using old ISO image: #{File.basename(OLD_TAILS_ISO)}"
  base = File.basename(feature.file, ".feature").to_s
  $background_snapshot = "#{$config["TMPDIR"]}/#{base}_background.state"
  $virt = Libvirt::open("qemu:///system")
  $vmnet = VMNet.new($virt, VM_XML_PATH)
  $vmstorage = VMStorage.new($virt, VM_XML_PATH)
end

AfterFeature('@product') do
  delete_snapshot($background_snapshot) if !KEEP_SNAPSHOTS
  $vmstorage.clear_pool
  $vmnet.destroy_and_undefine
  $virt.close
end

# BeforeScenario
Before('@product') do |scenario|
  @screen = Sikuli::Screen.new
  if $config["CAPTURE"]
    video_name = sanitize_filename("#{scenario.name}.mkv")
    @video_path = "#{ARTIFACTS_DIR}/#{video_name}"
    capture = IO.popen(['avconv',
                        '-f', 'x11grab',
                        '-s', '1024x768',
                        '-r', '15',
                        '-i', "#{$config['DISPLAY']}.0",
                        '-an',
                        '-c:v', 'libx264',
                        '-y',
                        @video_path,
                        :err => ['/dev/null', 'w'],
                       ])
    @video_capture_pid = capture.pid
  end
  if File.size?($background_snapshot)
    @skip_steps_while_restoring_background = true
  else
    @skip_steps_while_restoring_background = false
  end
  @theme = "gnome"
  # English will be assumed if this is not overridden
  @language = ""
  @os_loader = "MBR"
end

# AfterScenario
After('@product') do |scenario|
  if @video_capture_pid
    # We can be incredibly fast at detecting errors sometimes, so the
    # screen barely "settles" when we end up here and kill the video
    # capture. Let's wait a few seconds more to make it easier to see
    # what the error was.
    sleep 3 if scenario.failed?
    Process.kill("INT", @video_capture_pid)
  end
  if scenario.failed?
    time_of_fail = Time.now - TIME_AT_START
    tmp = @screen.capture.getFilename
    screenshot_name = sanitize_filename("#{scenario.name}.png")
    screenshot_path = "#{ARTIFACTS_DIR}/#{screenshot_name}"
    FileUtils.mv(tmp, screenshot_path)
    STDERR.puts("Screenshot: #{screenshot_path}")
    if File.exist?(@video_path)
      STDERR.puts("Video: #{@video_path}")
    end
    secs = "%02d" % (time_of_fail % 60)
    mins = "%02d" % ((time_of_fail / 60) % 60)
    hrs  = "%02d" % (time_of_fail / (60*60))
    STDERR.puts "Scenario failed at time #{hrs}:#{mins}:#{secs}"
    if $config["PAUSE_ON_FAIL"]
      STDERR.puts ""
      STDERR.puts "Press ENTER to continue running the test suite"
      STDIN.gets
    end
  else
    if @video_path && File.exist?(@video_path) && not($config['CAPTURE_ALL'])
      FileUtils.rm(@video_path)
    end
  end
  @vm.destroy_and_undefine if @vm
end

After('@product', '~@keep_volumes') do
  $vmstorage.clear_volumes
end

Before('@product', '@check_tor_leaks') do |scenario|
  @tor_leaks_sniffer = Sniffer.new(sanitize_filename(scenario.name), $vmnet)
  @tor_leaks_sniffer.capture
end

After('@product', '@check_tor_leaks') do |scenario|
  @tor_leaks_sniffer.stop
  if scenario.passed?
    if @bridge_hosts.nil?
      expected_tor_nodes = get_all_tor_nodes
    else
      expected_tor_nodes = @bridge_hosts
    end
    leaks = FirewallLeakCheck.new(@tor_leaks_sniffer.pcap_file,
                                  :accepted_hosts => expected_tor_nodes)
    leaks.assert_no_leaks
  end
  @tor_leaks_sniffer.clear
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

After do
  if @after_scenario_hooks
    @after_scenario_hooks.each { |block| block.call }
  end
  @after_scenario_hooks = Array.new
end

BeforeFeature('@product', '@source') do |feature|
  raise "Feature #{feature.file} is tagged both @product and @source, " +
        "which is an impossible combination"
end

at_exit do
  delete_all_snapshots if !KEEP_SNAPSHOTS
end
