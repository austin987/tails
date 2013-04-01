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

class Sikuli::Region
  def wait_and_click(pic, time)
    # It's undocumented, but wait() returns the matched region, so we
    # compute the middle of it and click() there instead of letting
    # click() scan for the picture again.
    r = self.wait(pic, time)
    x = r.x + r.width/2
    y = r.y + r.height/2
    self.click(x, y)
  end
end

class Sikuli::Screen
  def hide_cursor()
    hover(self.width/2, self.height/2)
  end
end

# Configure sikuli
Sikuli::Config.run do |config|
  config.image_path = "#{Dir.pwd}/features/images/"
  config.logging = false
  config.highlight_on_find = false
end

