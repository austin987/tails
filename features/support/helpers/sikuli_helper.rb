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

# Since rjb imports Java classes without creating a corresponding
# Ruby class (it's just an instance of Rjb_JavaProxy) we can't
# monkey patch any class, so additional methods must be added
# to each Screen object.
# Also, due to limitations in Ruby's syntax we can't do:
#     def Sikuli::Screen.new
# so we work around it with the following vairable.
sikuli_script_proxy = Sikuli::Screen
$_original_sikuli_screen_new ||= Sikuli::Screen.method :new
def sikuli_script_proxy.new(*args)
  s = $_original_sikuli_screen_new.call(*args)
  def s.click_point(x, y)
    self.click(Sikuli::Location.new(x, y))
  end

  def s.wait_and_click(pic, time)
    self.click(self.wait(pic, time))
  end

  def s.hide_cursor
    self.hover(Sikuli::Location.new(self.w, self.h/2))
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
sikuli_settings.OcrDataPath = $tmp_dir
# sikuli_ruby, which we used before, defaulted to 0.9 minimum
# similarity, so all our current images are adapted to that value.
# Also, Sikuli's default of 0.7 is simply too low (many false
# positives).
sikuli_settings.MinSimilarity = 0.9
sikuli_settings.ActionLogs = $debug
sikuli_settings.DebugLogs = $debug
sikuli_settings.InfoLogs = $debug
sikuli_settings.ProfileLogs = $debug
