require 'java'
require 'rubygems'
Dir[Dir.pwd + "/cucumber/support/helpers/*.rb"].each do |file|
  require file
end


Before do
  @vm = VM.new
  @screen = Sikuli::Screen.new
end


After do
  @vm.stop
end
