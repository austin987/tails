require 'java'
require 'rubygems'
Dir[Dir.pwd + "/cucumber/support/helpers/*.rb"].each do |file|
  require file
end


Before do
  @vm = VM.new
  @screen = Sikuli::Screen.new
  @sniffer = Sniffer.new("TestSniffer", @vm.net.bridge_name, @vm.ip, @vm.ip6)
  @sniffer.capture
end


After do
  @sniffer.stop
  @vm.stop
end
