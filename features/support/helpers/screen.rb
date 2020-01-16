class FindFailed < StandardError
end

class Match

  attr_reader :w, :h, :x, :y, :image

  def initialize(image, screen, x, y, w, h)
    @image = image
    @screen = screen
    @x = x
    @y = y
    @w = w
    @h = h
  end

  def middle
    [@x + @w/2, @y + @h/2]
  end

  def hover(**opts)
    @screen.hover(*middle, **opts)
  end

  def click(**opts)
    @screen.click(*middle, **opts)
  end

end

class Screen

  attr_reader :w, :h

  def initialize
    @w = 1024
    @h = 768
  end

  def xdotool(*args)
    out = cmd_helper("xdotool " + args.map { |s| "\"#{s}\""} .join(' '))
    assert(out.empty?, "xdotool reported an error:\n" + out)
  end

  def match_screen(image, sensitivity, show_image)
    screenshot = "#{$config["TMPDIR"]}/screenshot.png"
    $vm.display.screenshot(screenshot)
    return OpenCV.matchTemplate("#{OPENCV_IMAGE_PATH}/#{image}",
                                screenshot, sensitivity, show_image)
  ensure
    FileUtils.rm_f(screenshot)
  end

  def find(pattern, **opts)
    opts[:log] = true if opts[:log].nil?
    opts[:sensitivity] ||= OPENCV_MIN_SIMILARITY
    if pattern.instance_of?(String)
      image = pattern
    elsif pattern.instance_of?(Match)
      image = pattern.image
    else
      raise "unsupported type: #{pattern.class}"
    end
    debug_log("Screen: trying to find #{image}") if opts[:log]
    p = match_screen(image, opts[:sensitivity], false)
    if p.nil?
      raise FindFailed.new("cannot find #{image} on the screen")
    end
    m = Match.new(image, self, *p)
    debug_log("Screen: found #{image} at (#{m.middle.join(', ')})")
    return m
  end

  def exists(pattern, **opts)
    opts[:log] = true if opts[:log].nil?
    return !!find(pattern, **opts)
  rescue
    debug_log("cannot find #{pattern} on the screen") if opts[:log]
    false
  end

  def wait(pattern, timeout, **opts)
    opts[:log] = true if opts[:log].nil?
    debug_log("Screen: waiting for #{pattern}") if opts[:log]
    try_for(timeout, delay: 0) do
      return find(pattern, **opts.clone.update(log: false))
    end
  rescue Timeout::Error
    raise FindFailed.new("cannot find #{pattern} on the screen")
  end

  def wait_vanish(pattern, timeout, **opts)
    opts[:log] = true if opts[:log].nil?
    debug_log("Screen: waiting for #{pattern} to vanish") if opts[:log]
    try_for(timeout, delay: 0) do
      not(exists(pattern, **opts.clone.update(log: false)))
    end
    debug_log("Screen: #{pattern} has vanished") if opts[:log]
    return nil
  rescue Timeout::Error
    raise FindFailed.new("can still find #{pattern} on the screen")
  end

  def find_any(patterns, **opts)
    opts[:log] = true if opts[:log].nil?
    debug_log("Screen: trying to find any of #{patterns.join(', ')}") if opts[:log]
    patterns.each do |pattern|
      begin
        return [pattern, find(pattern, **opts.clone.update(log: false))]
      rescue FindFailed
        # Ignore. We deal we'll throw an appropriate exception after
        # having looped through all patterns and found none of them.
      end
    end
    # If we've reached this point, none of the patterns could be found.
    raise FindFailed.new("can not find any of the patterns #{patterns} " +
                        "on the screen")
  end

  def exists_any(*args, **opts)
    return !!find_any(*args, **opts)
  rescue
    false
  end

  def wait_any(patterns, time, **opts)
    opts[:log] = true if opts[:log].nil?
    debug_log("Screen: waiting for any of #{patterns.join(', ')}") if opts[:log]
    try_for(time) do
      return find_any(patterns, **opts.clone.update(log: false))
    end
  rescue Timeout::Error
    raise FindFailed.new("can not find any of the patterns #{patterns} " +
                         "on the screen")
  end

  def press(*sequence)
    sequence.map! do |symbol|
      {
        'printscreen' => 'Print',
      }[symbol.downcase] or symbol
    end
    sequence = sequence.join('+')
    debug_log("Keyboard: pressing: #{sequence}")
    xdotool('key', '--clearmodifiers', sequence)
    return nil
  end

  def type(*args)
    args.each do |arg|
      if arg.instance_of?(String)
        debug_log("Keyboard: typing: #{arg}")
        xdotool('type', '--clearmodifiers', '--delay=60', arg)
      elsif arg.instance_of?(Array)
        press(*arg)
      else
        raise("Unsupported type: #{arg.class}")
      end
    end
    return nil
  end

  def hover(*args, **opts)
    opts[:log] = true if opts[:log].nil?
    case args.size
    when 1
      pattern = args[0]
      m = find(pattern, **opts)
      x, y = m.middle
    when 2
      x, y = args
    else
      raise "unsupported arguments: #{args}"
    end
    debug_log("Mouse: moving to (#{x}, #{y})") if opts[:log]
    xdotool('mousemove', x, y)
    return [x, y]
  end

  def hide_cursor
    hover(@w - 1, @h/2)
  end

  def click(*args, **opts)
    opts[:button] ||= 1
    opts[:button] = 1 if opts[:button] == 'left'
    opts[:button] = 2 if opts[:button] == 'middle'
    opts[:button] = 3 if opts[:button] == 'right'
    opts[:repeat] ||= 1
    opts[:repeat] = 2 if opts[:double]
    opts[:log] = true if opts[:log].nil?
    x, y = hover(*args, **opts.clone.update(log: false))
    action = "clicking"
    if opts[:repeat] == 2
      action = "double-#{action}"
    elsif opts[:repeat] > 2
      action = "#{action} (repeat: #{opts[:repeat]})"
    end
    button = {1 => 'left', 2 => 'middle', 3 => 'right'}[opts[:button]]
    debug_log("Mouse: #{action} #{button} button at (#{x}, #{y})") if opts[:log]
    xdotool('click', '--repeat', opts[:repeat], opts[:button])
    return [x, y]
  end

end

class ImageBumpFailed < StandardError
end

# This class is the same as Screen but with the image matching methods
# wrapped so failures (FindFailed) are intercepted, and we enter an
# interactive mode allowing images to be updated. Note that the the
# negative image matching methods (*_vanish()) are excepted (it
# doesn't make sense for them).
class ImageBumpingScreen

  def initialize
    @screen = Screen.new
  end

  def interactive_image_bump(image, opts = {})
    opts[:sensitivity] ||= OPENCV_MIN_SIMILARITY
    $interactive_image_bump_ignores ||= []
    if $interactive_image_bump_ignores.include?(image)
      raise ImageBumpFailed
    end
    message = "Failed to find #{image}"
    notify_user(message)
    STDERR.puts("Screen: #{message}, entering interactive image bumping mode")
    # Ring the ASCII bell for a helpful notification in most terminal
    # emulators.
    STDOUT.write "\a"
    loop do
      STDERR.puts(
        "\n" +
        "a: Automatic bump\n" +
        "r: Retry image (pro tip: manually update the image first!)\n" +
        "i: Ignore this image for the remaining of the run\n" +
        "d: Debugging REPL\n" +
        "q: Abort (to the FindFailed exception)"
      )
      c = STDIN.getch
      case c
      when 'a'
        [0.80, 0.70, 0.60, 0.50, 0.40, 0.30].each do |sensitivity|
          STDERR.puts "Trying with sensitivity #{sensitivity}..."
          p = @screen.match_screen(image, sensitivity, true)
          if p
            STDERR.puts "Found match! Accept? (y/n)"
            loop do
              c = STDIN.getch
              if c == 'y'
                FileUtils.cp("#{$config["TMPDIR"]}/last_opencv_match.png",
                             "#{OPENCV_IMAGE_PATH}/#{image}")
                return p
              elsif c == 'n' || c == 3.chr  # Ctrl+C => 3
                break
              end
            end
            break if c == 3.chr  # Ctrl+C => 3
          end
        end
        STDERR.puts "Failed to automatically bump image"
      when 'r'
        p = @screen.match_screen(image, opts[:sensitivity], true)
        if p.nil?
          STDERR.puts "Failed to find image"
        else
          STDERR.puts "Found match! Accept? (y/n)"
          c = STDIN.getch
          return p if c == 'y'
        end
      when 'i'
        $interactive_image_bump_ignores << image
        raise ImageBumpFailed
      when 'q', 3.chr  # Ctrl+C => 3
        raise ImageBumpFailed
      when 'd'
        binding.pry(quiet: true)
      end
    end
  end

  screen_methods = Screen.instance_methods - Object.instance_methods
  overrides = [:find, :exists, :wait, :find_any, :exists_any,
               :wait_any, :hover, :click]
  screen_methods.each do |m|
    if overrides.include?(m)
      define_method(m) do |*args, **opts|
        begin
          return @screen.method(m).call(*args, **opts)
        rescue FindFailed => e
          begin
            image = args.first
            return interactive_image_bump(image, **opts)
          rescue ImageBumpFailed
            raise e
          end
        end
      end
    else
      define_method(m) do |*args|
        return @screen.method(m).call(*args)
      end
    end
  end

end
