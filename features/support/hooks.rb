require 'fileutils'
require 'time'
require 'tmpdir'

# Run once, before any feature
AfterConfiguration do |config|
  # Used to keep track of when we start our first @product feature, when
  # we'll do some special things.
  $started_first_product_feature = false
end

# For @product tests
####################

def add_after_scenario_hook(&block)
  @after_scenario_hooks ||= Array.new
  @after_scenario_hooks << block
end

BeforeFeature('@product') do |feature|
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
      Dir.mkdir($config["TMPDIR"])
    rescue Errno::EACCES => e
      raise "Cannot create temporary directory: #{e.to_s}"
    end
  end
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
  if not($started_first_product_feature)
    $virt = Libvirt::open("qemu:///system")
    VM.remove_all_snapshots if !KEEP_SNAPSHOTS
    $vmnet = VMNet.new($virt, VM_XML_PATH)
    $vmstorage = VMStorage.new($virt, VM_XML_PATH)
    $started_first_product_feature = true
  end
end

BeforeFeature('@product', '@old_iso') do
  if OLD_TAILS_ISO.nil?
    raise "No old Tails ISO image specified, and none could be found in the " +
          "current directory"
  end
  if !File.exist?(OLD_TAILS_ISO)
    raise "The specified old Tails ISO image '#{OLD_TAILS_ISO}' does not exist"
  end
  if TAILS_ISO == OLD_TAILS_ISO
    raise "The old Tails ISO is the same as the Tails ISO we're testing"
  end
  puts "Using old ISO image: #{File.basename(OLD_TAILS_ISO)}"
end

# BeforeScenario
Before('@product') do
  @screen = Sikuli::Screen.new
  @theme = "gnome"
  # English will be assumed if this is not overridden
  @language = ""
  @os_loader = "MBR"
  @sudo_password = "asdf"
  @persistence_password = "asdf"
end

# AfterScenario
After('@product') do |scenario|
  if scenario.failed?
    time_of_fail = Time.now - TIME_AT_START
    secs = "%02d" % (time_of_fail % 60)
    mins = "%02d" % ((time_of_fail / 60) % 60)
    hrs  = "%02d" % (time_of_fail / (60*60))
    STDERR.puts "Scenario failed at time #{hrs}:#{mins}:#{secs}"
    base = File.basename(scenario.feature.file, ".feature").to_s
    tmp = @screen.capture.getFilename
    out = "#{$config["TMPDIR"]}/#{base}-#{DateTime.now}.png"
    FileUtils.mv(tmp, out)
    STDERR.puts("Took screenshot \"#{out}\"")
    if $config["PAUSE_ON_FAIL"]
      STDERR.puts ""
      STDERR.puts "Press ENTER to continue running the test suite"
      STDIN.gets
    end
  end
end

Before('@product', '@check_tor_leaks') do |scenario|
  feature_file_name = File.basename(scenario.feature.file, ".feature").to_s
  @tor_leaks_sniffer = Sniffer.new(feature_file_name + "_sniffer", $vmnet)
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
  $vm.destroy_and_undefine if $vm
  if $virt
    unless KEEP_SNAPSHOTS
      VM.remove_all_snapshots
      $vmstorage.clear_pool
    end
    $vmnet.destroy_and_undefine
    $virt.close
  end
end
