require 'fileutils'
require 'rb-inotify'
require 'time'
require 'tmpdir'

# Run once, before any feature
AfterConfiguration do |config|
  # Reorder the execution of some features. As we progress through a
  # run we accumulate more and more snapshots and hence use more and
  # more disk space, but some features will leave nothing behind
  # and/or possibly use large amounts of disk space temporarily for
  # various reasons. By running these first we minimize the amount of
  # disk space needed.
  prioritized_features = [
    # Features not using snapshots but using large amounts of scratch
    # space for other reasons:
    'features/erase_memory.feature',
    'features/untrusted_partitions.feature',
    # Features using temporary snapshots:
    'features/apt.feature',
    'features/i2p.feature',
    'features/root_access_control.feature',
    'features/time_syncing.feature',
    'features/tor_bridges.feature',
    # This feature needs the almost biggest snapshot (USB install,
    # excluding persistence) and will create yet another disk and
    # install Tails on it. This should be the peak of disk usage.
    'features/usb_install.feature',
  ]
  feature_files = config.feature_files
  # The &-intersection is specified to keep the element ordering of
  # the *left* operand.
  intersection = prioritized_features & feature_files
  if not intersection.empty?
    feature_files -= intersection
    feature_files = intersection + feature_files
    config.define_singleton_method(:feature_files) { feature_files }
  end

  # Used to keep track of when we start our first @product feature, when
  # we'll do some special things.
  $started_first_product_feature = false

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
  $vm.destroy_and_undefine if $vm
  if $virt
    unless KEEP_SNAPSHOTS
      VM.remove_all_snapshots
      $vmstorage.clear_pool
    end
    $vmnet.destroy_and_undefine
    $virt.close
  end
  # The artifacts directory is empty (and useless) if it contains
  # nothing but the mandatory . and ..
  if Dir.entries(ARTIFACTS_DIR).size <= 2
    FileUtils.rmdir(ARTIFACTS_DIR)
  end
end

# For @product tests
####################

def add_after_scenario_hook(&block)
  @after_scenario_hooks ||= Array.new
  @after_scenario_hooks << block
end

def save_failure_artifact(type, path)
  $failure_artifacts << [type, path]
end

# Due to Tails' Tor enforcement, we only allow contacting hosts that
# are Tor (or I2P) nodes or located on the LAN. However, when we try
# to verify that only such hosts are contacted we have a problem --
# we run all Tor nodes (via Chutney) *and* LAN hosts (used on some
# tests) on the same host, the one running the test suite. Hence we
# need to always explicitly track which nodes are LAN or not.
#
# Warning: when a host is added via this function, it is only added
# for the current scenario. As such, if this is done before saving a
# snapshot, it will not remain after the snapshot is loaded.
def add_lan_host(ipaddr, port)
  @lan_hosts ||= []
  @lan_hosts << { address: ipaddr, port: port }
end

BeforeFeature('@product') do |feature|
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
  if !File.exist?(OLD_TAILS_ISO)
    raise "The specified old Tails ISO image '#{OLD_TAILS_ISO}' does not exist"
  end
  if not($started_first_product_feature)
    $virt = Libvirt::open("qemu:///system")
    VM.remove_all_snapshots if !KEEP_SNAPSHOTS
    $vmnet = VMNet.new($virt, VM_XML_PATH)
    $vmstorage = VMStorage.new($virt, VM_XML_PATH)
    $started_first_product_feature = true
  end
  ensure_chutney_is_running
end

AfterFeature('@product') do
  unless KEEP_SNAPSHOTS
    checkpoints.each do |name, vals|
      if vals[:temporary] and VM.snapshot_exists?(name)
        VM.remove_snapshot(name)
      end
    end
  end
end

# Cucumber Before hooks are executed in the order they are listed, and
# we want this hook to always run first, so it must always be the
# *first* Before hook matching @product listed in this file.
Before('@product') do |scenario|
  $failure_artifacts = Array.new
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
  @screen = Sikuli::Screen.new
  # English will be assumed if this is not overridden
  @language = ""
  @os_loader = "MBR"
  @sudo_password = "asdf"
  @persistence_password = "asdf"
  # See comment for add_lan_host() above.
  @lan_hosts ||= []
end

# Cucumber After hooks are executed in the *reverse* order they are
# listed, and we want this hook to always run second last, so it must always
# be the *second* After hook matching @product listed in this file --
# hooks added dynamically via add_after_scenario_hook() are supposed to
# truly be last.
After('@product') do |scenario|
  if @video_capture_pid
    # We can be incredibly fast at detecting errors sometimes, so the
    # screen barely "settles" when we end up here and kill the video
    # capture. Let's wait a few seconds more to make it easier to see
    # what the error was.
    sleep 3 if scenario.failed?
    Process.kill("INT", @video_capture_pid)
    save_failure_artifact("Video", @video_path)
  end
  if scenario.failed?
    time_of_fail = Time.now - TIME_AT_START
    secs = "%02d" % (time_of_fail % 60)
    mins = "%02d" % ((time_of_fail / 60) % 60)
    hrs  = "%02d" % (time_of_fail / (60*60))
    elapsed = "#{hrs}:#{mins}:#{secs}"
    info_log("Scenario failed at time #{elapsed}")
    screen_capture = @screen.capture
    save_failure_artifact("Screenshot", screen_capture.getFilename)
    $failure_artifacts.sort!
    $failure_artifacts.each do |type, file|
      artifact_name = sanitize_filename("#{elapsed}_#{scenario.name}#{File.extname(file)}")
      artifact_path = "#{ARTIFACTS_DIR}/#{artifact_name}"
      assert(File.exist?(file))
      FileUtils.mv(file, artifact_path)
      info_log
      info_log_artifact_location(type, artifact_path)
    end
    pause("Scenario failed") if $config["PAUSE_ON_FAIL"]
  else
    if @video_path && File.exist?(@video_path) && not($config['CAPTURE_ALL'])
      FileUtils.rm(@video_path)
    end
  end
end

Before('@product', '@check_tor_leaks') do |scenario|
  @tor_leaks_sniffer = Sniffer.new(sanitize_filename(scenario.name), $vmnet)
  @tor_leaks_sniffer.capture
  add_after_scenario_hook do
    @tor_leaks_sniffer.clear
  end
end

After('@product', '@check_tor_leaks') do |scenario|
  @tor_leaks_sniffer.stop
  if scenario.passed?
    allowed_nodes = @bridge_hosts ? @bridge_hosts : allowed_hosts_under_tor_enforcement
    assert_all_connections(@tor_leaks_sniffer.pcap_file) do |c|
      allowed_nodes.include?({ address: c.daddr, port: c.dport })
    end
  end
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
