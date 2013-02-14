require 'sikuli'

# Add missing stuff
module Sikuli
  KEY_F1 = "\356\200\221"
  KEY_F2 = "\356\200\222"
  KEY_F3 = "\356\200\223"
  KEY_F4 = "\356\200\224"
  KEY_F5 = "\356\200\225"
  KEY_F6 = "\356\200\226"
  KEY_F7 = "\356\200\227"
  KEY_F8 = "\356\200\228"
  KEY_F9 = "\356\200\229"
  KEY_F10 = "\356\200\230"
  KEY_F11 = "\356\200\231"
  KEY_F12 = "\356\200\232"
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

