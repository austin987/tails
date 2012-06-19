require 'java'
require 'rubygems'
Dir[File.dirname(__FILE__) + "/features/support/helpers/*.rb"].each do |file|
  require file
end


Before do
  @vm = VM.new(ENV['VM'])
  @display = Display.new(ENV['VM'])
  @screen = Sikuli::Screen.new
end


After do
  @display.stop
  @vm.stop
end
