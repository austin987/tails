require 'java'
require 'rubygems'
require 'time'

Before do |scenario|
  $tmp_dir = ENV['TEMP_DIR']
  if ! $already_run
    # This code runs *exactly once*, before the *first* feature
    $time_at_start = Time.now
    $already_run = true
  end
  @screen = Sikuli::Screen.new
  @feature = File.basename(scenario.feature.file, ".feature").to_s
  @background_snapshot = "#{$tmp_dir}/#{@feature}_background.state"
  @skip_steps_while_restoring_background = false
  @theme = "gnome"
  if $prev_feature != @feature
    # This code runs before the *first* scenario's background for *each* feature
    # FIXME: We can't use this yet due to permission issues.
#    if File.exist? @background_snapshot
#      File.delete @background_snapshot
#    end
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
  @vm.destroy
end
