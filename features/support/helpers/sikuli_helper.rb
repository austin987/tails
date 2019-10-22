require 'rjb'
require 'rjbextension'
$LOAD_PATH << ENV['SIKULI_HOME']
require 'sikulixapi.jar'
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
                   "org.sikuli.basics.Settings",
                   "org.sikuli.script.ImagePath",
                  ]

# Note: we can't use anything that starts with "Java" on the right
# side, otherwise the :Java constant is defined and then
# test/unit/assertions will use JRuby-specific code that breaks our
# own code.
translations = Hash[
                    "org.sikuli.script", "Sikuli",
                    "org.sikuli.basics", "Sikuli",
                    "java.lang", "RJava::Lang",
                    "java.io", "RJava::Io",
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
  file_output_stream = RJava::Io::FileOutputStream.new(DEBUG_LOG_PSEUDO_FIFO)
  print_stream = RJava::Io::PrintStream.new(file_output_stream)
  RJava::Lang::System.setOut(print_stream)
end

class FindFailedHookFailure < StandardError
end

def findfailed_hook(proxy, orig_method, args)
  picture = args.first
  candidate_path = "#{SIKULI_CANDIDATES_DIR}/#{picture}"
  if $config['SIKULI_FUZZY_IMAGE_MATCHING']
    if ! File.exist?(candidate_path)
      [0.80, 0.70, 0.60, 0.50, 0.40].each do |similarity|
        pattern = Sikuli::Pattern.new(picture)
        pattern.similar(similarity)
        match = proxy._invoke('exists', 'Ljava.lang.Object;', pattern)
        if match
          capture = proxy._invoke('capture', 'Lorg.sikuli.script.Region;', match)
          capture_path = capture.getFilename
          # Let's verify that our screen capture actually matches
          # with the default similarity
          if proxy._invoke('exists', 'Ljava.lang.Object;', capture_path)
            debug_log("Found fuzzy candidate picture for #{picture} with " +
                      "similarity #{similarity}")
            FileUtils.mkdir_p(SIKULI_CANDIDATES_DIR)
            FileUtils.mv(capture_path, candidate_path)
            break
          else
            FileUtils.rm(capture_path)
          end
        end
      end
      if ! File.exist?(candidate_path)
        debug_log("Failed to find fuzzy candidate picture for #{picture}")
      end
    end

    if File.exist?(candidate_path)
      debug_log("Using fuzzy candidate picture for #{picture}")
      args_with_candidate = [candidate_path] + args.drop(1)
      return orig_method.call(*args_with_candidate)
    end

  end  # if $config['SIKULI_FUZZY_IMAGE_MATCHING']

  if $config["SIKULI_RETRY_FINDFAILED"]
    pause("FindFailed for: '#{picture}'")
    return orig_method.call(*args)
  else
    raise FindFailedHookFailure
  end
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
sikuli_screen_proxy = Sikuli::Screen
$_original_sikuli_screen_new ||= Sikuli::Screen.method :new

# For waitAny()/findAny() we are forced to throw this exception since
# Rjb::throw doesn't block until the Java exception has been received
# by Ruby, so strange things can happen.
class FindAnyFailed < StandardError
end

def sikuli_screen_proxy.new(*args)
  s = $_original_sikuli_screen_new.call(*args)

  findfail_overrides = [
    ['click', 'Ljava.lang.Object;'],
    ['find', 'Ljava.lang.Object;'],
    ['wait', 'Ljava.lang.Object;D'],
  ]

  # The usage of `_invoke()` below exemplifies how one can wrap
  # around Java objects' methods when they're imported using RJB. It
  # isn't pretty. The seconds argument is the parameter signature,
  # which can be obtained by creating the intended Java object using
  # RJB, and then calling its `java_methods` method.
  findfail_overrides.each do |method_name, signature|
    s.define_singleton_method("#{method_name}_no_override") do |*args|
      begin
        self._invoke(method_name, signature, *args)
      end
    end
    s.define_singleton_method(method_name) do |*args|
      begin
        args_desc = ''
        if args.first.instance_of?(Rjb::Rjb_JavaProxy)
          args_desc = args.first.toString
        else
          args_desc = '"' + args.first.to_s + '"'
        end
        debug_log("Sikuli: calling #{method_name}(#{args_desc})...")
        orig_method = s.method("#{method_name}_no_override")
        return orig_method.call(*args)
      rescue Exception => exception
        # We really would like to only capture the FindFailed
        # exceptions imported by rjb here, but that hasn't happened
        # at the time this code is run. Yeah, meta-programming! :)
        if exception.class.name == "FindFailed"
          begin
            return findfailed_hook(self, orig_method, args)
          rescue FindFailedHookFailure
            debug_log("FindFailedHookFailure was raised, re-running the failing Sikuli method.")
            # Due to bugs in rjb we cannot re-throw Java exceptions,
            # which is what we want now. Instead we have to resort to
            # a hack: let's re-run the failing Sikuli method to
            # (hopefully) reproduce the exception.
            # Upstream bug details:
            # * https://github.com/arton/rjb/issues/59
            # * https://github.com/arton/rjb/issues/60
            new_args = args
            if new_args.size > 1 && new_args[-1].is_a?(Numeric)
              # Optimize the timeout
              new_args[-1] = 0.01
            end
            # There are situations where we actually could succeed
            # now, e.g. if we timed out looking for an image *just*
            # before it appeared, so it is first visible exactly when
            # we arrive here. If so, well, let's enjoy!
            return orig_method.call(*new_args)
          end
        else
          raise exception
        end
      end
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
        return [image, self.find_no_override(image)]
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
    self.hover_point(self.w - 1, self.h/2)
  end

  s
end

# Configure sikuli
Sikuli::ImagePath.add(SIKULI_IMAGE_PATH)
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
sikuli_settings.MinSimilarity = SIKULI_MIN_SIMILARITY
sikuli_settings.ActionLogs = true
sikuli_settings.DebugLogs = true
sikuli_settings.InfoLogs = true
sikuli_settings.ProfileLogs = false
