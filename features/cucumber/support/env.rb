require 'java'
require 'rubygems'
Dir[Dir.pwd + "/cucumber/support/helpers/*.rb"].each do |file|
  require file
end


Before do
  @vm = VM.new
  @display = Display.new(@vm.domain.name)
  @screen = Sikuli::Screen.new
end


After do
  @display.stop
  @vm.stop
end
