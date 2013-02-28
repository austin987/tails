require 'java'
require 'rubygems'
require 'time'

$time_at_start = Time.now
$tmp_dir = ENV['TEMP_DIR']
$vm_xml_path = ENV['VM_XML_PATH'] || "#{Dir.pwd}/features/cucumber/domains"
$tails_iso = ENV['ISO'] || get_last_iso
$x_display = ENV['DISPLAY']

Before do |scenario|
  @screen = Sikuli::Screen.new
  @feature = File.basename(scenario.feature.file, ".feature").to_s
  @background_snapshot = "#{$tmp_dir}/#{@feature}_background.state"
  @skip_steps_while_restoring_background = false
  @theme = "gnome"
  if $prev_feature != @feature
    # This code runs before the *first* scenario's background for *each* feature

    # Remove existing leftover background snapshot so we run the
    # feature from scratch
    if File.exist?(@background_snapshot)
      File.delete(@background_snapshot)
    end
    # Workaround for libvirt permission issues. See the run_test_suite
    # script for more information about a similar libvirt premission issue.
    FileUtils.touch(@background_snapshot)
    FileUtils.chmod(0666, @background_snapshot)
  end
  $prev_feature = @feature
end


After do |scenario|
  if (scenario.status != :passed)
    time_of_fail = Time.now - $time_at_start
    secs = "%02d" % (time_of_fail % 60)
    mins = "%02d" % ((time_of_fail / 60) % 60)
    hrs  = "%02d" % (time_of_fail / (60*60))
    STDERR.puts "Scenario failed at time #{hrs}:#{mins}:#{secs}"
    @vm.take_screenshot("#{@feature}-#{DateTime.now}") if @vm
  end
  @sniffer.stop if @sniffer
  @vm.destroy if @vm
end
