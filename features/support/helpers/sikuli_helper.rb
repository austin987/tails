require 'rjb'
require 'rjbextension'
$LOAD_PATH << ENV['SIKULI_HOME']
require 'sikuli-script.jar'
Rjb::load

package_members = [
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

def findfailed_hook(pic)
  STDERR.puts ""
  STDERR.puts "FindFailed for: #{pic}"
  STDERR.puts ""
  STDERR.puts "Update the image and press RETURN to retry"
  STDIN.gets
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
sikuli_settings.OcrDataPath = $config["TMP_DIR"]
# sikuli_ruby, which we used before, defaulted to 0.9 minimum
# similarity, so all our current images are adapted to that value.
# Also, Sikuli's default of 0.7 is simply too low (many false
# positives).
sikuli_settings.MinSimilarity = 0.9
sikuli_settings.ActionLogs = $config["DEBUG"]
sikuli_settings.DebugLogs = $config["DEBUG"]
sikuli_settings.InfoLogs = $config["DEBUG"]
sikuli_settings.ProfileLogs = $config["DEBUG"]
