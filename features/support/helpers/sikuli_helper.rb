require 'rjb'
require 'rjbextension'
$LOAD_PATH << ENV['SIKULI_HOME']
require 'sikuli-script.jar'
Rjb::load

package_members = [
                   "java.io.FileOutputStream",
                   "java.io.PrintStream",
                   "java.lang.System",
                   "org.sikuli.script.Finder",
                   "org.sikuli.script.Key",
                   "org.sikuli.script.KeyModifier",
                   "org.sikuli.script.Location",
                   "org.sikuli.script.Match",
                   "org.sikuli.script.Pattern",
                   "org.sikuli.script.Region",
                   "org.sikuli.script.Screen",
                   "org.sikuli.script.Settings",
                  ]

translations = Hash[
                    "org.sikuli.script", "Sikuli",
                    "java.lang", "Java::Lang",
                    "java.io", "Java::Io",
                   ]

for p in package_members
  imported_class = Rjb::import(p)
  package, ignore, class_name = p.rpartition(".")
  next if ! translations.include? package
  mod_name = translations[package]
  mod = mod_name.split("::").inject(Object) do |parent_obj, child_name|
    if parent_obj.const_defined?(child_name, false)
      parent_obj.const_get(child_name, false)
    else
      child_obj = Module.new
      parent_obj.const_set(child_name, child_obj)
    end
  end
  mod.const_set(class_name, imported_class)
end

# Bind Java's stdout to debug_log() via our magical pseudo fifo
# logger.
def bind_java_to_pseudo_fifo_logger
  file_output_stream = Java::Io::FileOutputStream.new(DEBUG_LOG_PSEUDO_FIFO)
  print_stream = Java::Io::PrintStream.new(file_output_stream)
  Java::Lang::System.setOut(print_stream)
end

def findfailed_hook(pic)
  pause("FindFailed for: '#{pic}'")
end

# Since rjb imports Java classes without creating a corresponding
# Ruby class (it's just an instance of Rjb_JavaProxy) we can't
# monkey patch any class, so additional methods must be added
# to each Screen object.
#
# All Java classes' methods are immediately available in the proxied
# Ruby classes, but care has to be given to match their type. For a
# list of methods, see: <http://doc.sikuli.org/javadoc/index.html>.
# The type "PRSML" is a union of Pattern, Region, Screen, Match and
# Location.
#
# Also, due to limitations in Ruby's syntax we can't do:
#     def Sikuli::Screen.new
# so we work around it with the following vairable.
sikuli_script_proxy = Sikuli::Screen
$_original_sikuli_screen_new ||= Sikuli::Screen.method :new

# For waitAny()/findAny() we are forced to throw this exception since
# Rjb::throw doesn't block until the Java exception has been received
# by Ruby, so strange things can happen.
class FindAnyFailed < StandardError
end

def sikuli_script_proxy.new(*args)
  s = $_original_sikuli_screen_new.call(*args)

  if $config["SIKULI_RETRY_FINDFAILED"]
    # The usage of `_invoke()` below exemplifies how one can wrap
    # around Java objects' methods when they're imported using RJB. It
    # isn't pretty. The seconds argument is the parameter signature,
    # which can be obtained by creating the intended Java object using
    # RJB, and then calling its `java_methods` method.

    def s.wait(pic, time)
      self._invoke('wait', 'Ljava.lang.Object;D', pic, time)
    rescue FindFailed => e
      findfailed_hook(pic)
      self._invoke('wait', 'Ljava.lang.Object;D', pic, time)
    end

    def s.find(pic)
      self._invoke('find', 'Ljava.lang.Object;', pic)
    rescue FindFailed => e
      findfailed_hook(pic)
      self._invoke('find', 'Ljava.lang.Object;', pic)
    end

    def s.waitVanish(pic, time)
      self._invoke('waitVanish', 'Ljava.lang.Object;D', pic, time)
    rescue FindFailed => e
      findfailed_hook(pic)
      self._invoke('waitVanish', 'Ljava.lang.Object;D', pic, time)
    end

    def s.click(pic)
      self._invoke('click', 'Ljava.lang.Object;', pic)
    rescue FindFailed => e
      findfailed_hook(pic)
      self._invoke('click', 'Ljava.lang.Object;', pic)
    end
  end

  def s.click_point(x, y)
    self.click(Sikuli::Location.new(x, y))
  end

  def s.doubleClick_point(x, y)
    self.doubleClick(Sikuli::Location.new(x, y))
  end

  def s.click_mid_right_edge(pic)
    r = self.find(pic)
    top_right = r.getTopRight()
    x = top_right.getX
    y = top_right.getY + r.getH/2
    self.click_point(x, y)
  end

  def s.wait_and_click(pic, time)
    self.click(self.wait(pic, time))
  end

  def s.wait_and_double_click(pic, time)
    self.doubleClick(self.wait(pic, time))
  end

  def s.wait_and_right_click(pic, time)
    self.rightClick(self.wait(pic, time))
  end

  def s.wait_and_hover(pic, time)
    self.hover(self.wait(pic, time))
  end

  def s.existsAny(images)
    images.each do |image|
      region = self.exists(image)
      return [image, region] if region
    end
    return nil
  end

  def s.findAny(images)
    images.each do |image|
      begin
        return [image, self.find(image)]
      rescue FindFailed
        # Ignore. We deal we'll throw an appropriate exception after
        # having looped through all images and found none of them.
      end
    end
    # If we've reached this point, none of the images could be found.
    raise FindAnyFailed.new("can not find any of the images #{images} on the " +
                            "screen")
  end

  def s.waitAny(images, time)
    Timeout::timeout(time) do
      loop do
        result = self.existsAny(images)
        return result if result
      end
    end
  rescue Timeout::Error
    raise FindAnyFailed.new("can not find any of the images #{images} on the " +
                            "screen")
  end

  def s.hover_point(x, y)
    self.hover(Sikuli::Location.new(x, y))
  end

  def s.hide_cursor
    self.hover_point(self.w, self.h/2)
  end

  s
end

# Configure sikuli
java.lang.System.setProperty("SIKULI_IMAGE_PATH", "#{Dir.pwd}/features/images/")

# ruby and rjb doesn't play well together when it comes to static
# fields (and possibly methods) so we instantiate and access the field
# via objects instead. It actually works inside this file, but when
# it's required from "outside", and the file has been completely
# required, ruby's require method complains that the method for the
# field accessor is missing.
sikuli_settings = Sikuli::Settings.new
sikuli_settings.OcrDataPath = $config["TMPDIR"]
# sikuli_ruby, which we used before, defaulted to 0.9 minimum
# similarity, so all our current images are adapted to that value.
# Also, Sikuli's default of 0.7 is simply too low (many false
# positives).
sikuli_settings.MinSimilarity = 0.9
sikuli_settings.ActionLogs = true
sikuli_settings.DebugLogs = true
sikuli_settings.InfoLogs = true
sikuli_settings.ProfileLogs = true
