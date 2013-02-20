require 'java'
require 'rubygems'

Before do |scenario|
  new_tails_instance
  @screen = Sikuli::Screen.new
  @sniffer = Sniffer.new("TestSniffer", @vm.net.bridge_name, @vm.ip, @vm.ip6)
  @sniffer.capture
  @feature = File.basename(scenario.feature.file, ".feature").to_s
  @background_snapshot = "#{Dir.pwd}/features/tmpfs/#{@feature}_background.state"
  @skip_steps_while_restoring_background = false
  @theme = "gnome"
  if $prev_feature != @feature
    # This code runs before the *first* scenario's background for each feature
    # FIXME: We can't use this yet, due to permission issues.
#    if File.exist? @background_snapshot
#      File.delete @background_snapshot
#    end
  end
  $prev_feature = @feature
end


After do |scenario|
  if (scenario.status != :passed)
    @vm.take_screenshot("#{@feature}-#{DateTime.now}")
  end
  @sniffer.stop
  @vm.stop
end
