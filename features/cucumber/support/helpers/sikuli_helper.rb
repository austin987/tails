require 'sikuli'

# Add missing stuff
module Sikuli
  KEY_F2 = "\356\200\222"
end

module Sikuli::Clickable
  def hover(x, y)
    @java_obj.hover(org.sikuli.script::Location.new(x, y).offset(x(), y()))
  end
end

class Sikuli::Screen
  def hide_cursor()
    hover(self.width, self.height)
  end
end

# Configure sikuli
Sikuli::Config.run do |config|
  config.image_path = "#{Dir.pwd}/features/cucumber/images/"
  config.logging = false
  config.highlight_on_find = false
end

