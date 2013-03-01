require 'java'
require 'rubygems'
require 'time'
require "#{Dir.pwd}/features/cucumber/support/extra_hooks.rb"

$time_at_start = Time.now
$tmp_dir = ENV['TEMP_DIR']
$vm_xml_path = ENV['VM_XML_PATH'] || "#{Dir.pwd}/features/cucumber/domains"
$tails_iso = ENV['ISO'] || get_last_iso
$x_display = ENV['DISPLAY']

BeforeFeature do |feature|
  base = File.basename(feature.file, ".feature").to_s
  $background_snapshot = "#{$tmp_dir}/#{base}_background.state"
end

AfterFeature do |feature|
  if File.exist?($background_snapshot)
    File.delete($background_snapshot)
  end
  VM.storage.clear_volumes
end

# BeforeScenario
Before do
  @screen = Sikuli::Screen.new
  if File.size?($background_snapshot)
    @skip_steps_while_restoring_background = true
  else
    @skip_steps_while_restoring_background = false
  end
  @theme = "gnome"
end

# AfterScenario
After do |scenario|
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

at_exit do
  VM.storage.clear_pool
end
