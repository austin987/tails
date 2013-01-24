require 'java'
require 'rubygems'
Dir["#{Dir.pwd}/features/cucumber/support/helpers/*.rb"].each do |file|
  require file
end


Before do |scenario|
  @vm = VM.new
  @screen = Sikuli::Screen.new
  @sniffer = Sniffer.new("TestSniffer", @vm.net.bridge_name, @vm.ip, @vm.ip6)
  @sniffer.capture
  @feature = File.basename(scenario.feature.file, ".feature")
  @background_snapshot = "#{Dir.pwd}/features/tmpfs/#{@feature}_background.state"
  @skip_steps_while_restoring_background = false
end


After do
  @sniffer.stop
  @vm.stop
end
