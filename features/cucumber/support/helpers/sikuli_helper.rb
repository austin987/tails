require 'sikuli'

# Add missing stuff
module Sikuli
  KEY_F1 = Key::F1
  KEY_F2 = Key::F2
  KEY_F3 = Key::F3
  KEY_F4 = Key::F4
  KEY_F5 = Key::F5
  KEY_F6 = Key::F6
  KEY_F7 = Key::F7
  KEY_F8 = Key::F8
  KEY_F9 = Key::F9
  KEY_F10 = Key::F10
  KEY_F11 = Key::F11
  KEY_F12 = Key::F12
  KEY_ESC = Key::ESC
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

