class FindFailed < StandardError
end

class Match
  attr_reader :w, :h, :x, :y, :image

  def initialize(image, screen, x, y, w, h) # rubocop:disable Metrics/ParameterLists
    @image = image
    @screen = screen
    @x = x
    @y = y
    @w = w
    @h = h
  end

  def middle
    [@x + @w / 2, @y + @h / 2]
  end

  def hover(**opts)
    @screen.hover(*middle, **opts)
  end

  def click(**opts)
    @screen.click(*middle, **opts)
  end
end

class Keymaps
  # Values extracted from the virkeyname-linux(7) man page. These are the
  # keys that tend to be the same on all keyboards, no matter locale.
  # Beware that this has not been tested/verified thoroughly!
  COMMON_KEYMAP = {
    'a' => [0x1e], 'b' => [0x30], 'c' => [0x2e], 'd' => [0x20], 'e' => [0x12],
    'f' => [0x21], 'g' => [0x22], 'h' => [0x23], 'i' => [0x17], 'j' => [0x24],
    'k' => [0x25], 'l' => [0x26], 'm' => [0x32], 'n' => [0x31], 'o' => [0x18],
    'p' => [0x19], 'q' => [0x10], 'r' => [0x13], 's' => [0x1f], 't' => [0x14],
    'u' => [0x16], 'v' => [0x2f], 'w' => [0x11], 'x' => [0x2d], 'y' => [0x15],
    'z' => [0x2c],

    'A' => [0x2a, 0x1e], 'B' => [0x2a, 0x30], 'C' => [0x2a, 0x2e],
    'D' => [0x2a, 0x20], 'E' => [0x2a, 0x12], 'F' => [0x2a, 0x21],
    'G' => [0x2a, 0x22], 'H' => [0x2a, 0x23], 'I' => [0x2a, 0x17],
    'J' => [0x2a, 0x24], 'K' => [0x2a, 0x25], 'L' => [0x2a, 0x26],
    'M' => [0x2a, 0x32], 'N' => [0x2a, 0x31], 'O' => [0x2a, 0x18],
    'P' => [0x2a, 0x19], 'Q' => [0x2a, 0x10], 'R' => [0x2a, 0x13],
    'S' => [0x2a, 0x1f], 'T' => [0x2a, 0x14], 'U' => [0x2a, 0x16],
    'V' => [0x2a, 0x2f], 'W' => [0x2a, 0x11], 'X' => [0x2a, 0x2d],
    'Y' => [0x2a, 0x15], 'Z' => [0x2a, 0x2c],

    '1' => [0x02], '2' => [0x03], '3' => [0x04], '4' => [0x05],
    '5' => [0x06], '6' => [0x07], '7' => [0x08], '8' => [0x09],
    '9' => [0x0a], '0' => [0x0b],

    'f1' => [0x3b], 'f2' => [0x3c], 'f3' => [0x3d], 'f4' => [0x3e],
    'f5' => [0x3f], 'f6' => [0x40], 'f7' => [0x41], 'f8' => [0x42],
    'f9' => [0x43], 'f10' => [0x44], 'f11' => [0x57], 'f12' => [0x58],

    'page_up' => [0x68], 'page_down' => [0x6d], 'home' => [0x66],
    'end' => [0x6b], 'insert' => [0x6e], 'delete' => [0x6f],
    'up' => [0x67], 'down' => [0x6c], 'left' => [0x69], 'right' => [0x6a],
    'escape' => [0x01], 'backspace' => [0x0e],
    'printscreen' => [0x63], 'sysrq' => [0x63],
    'space' => [0x39], ' ' => [0x39],
    'return' => [0x1c], 'enter' => [0x1c], "\n" => [0x1c],
    'tab' => [0x0f], "\t" => [0x0f],
    'alt' => [0x38], 'right_alt' => [0x64],
    'ctrl' => [0x1d], 'right_ctrl' => [0x61],
    'shift' => [0x2a], 'right_shift' => [0x36],
  }.freeze

  US_KEYMAP = COMMON_KEYMAP.merge(
    {
      '-' => [0x0c], '=' => [0x0d], ';' => [0x27], "'" => [0x28],
      '`' => [0x29], '\\' => [0x2b], ',' => [0x33], '.' => [0x34],
      '/' => [0x35], '<' => [0x56], '[' => [0x1a], ']' => [0x1b],
      '!' => [0x2a, 0x02], '@' => [0x2a, 0x03], '#' => [0x2a, 0x04],
      '$' => [0x2a, 0x05], '%' => [0x2a, 0x06], '^' => [0x2a, 0x07],
      '&' => [0x2a, 0x08], '*' => [0x2a, 0x09], '(' => [0x2a, 0x0a],
      ')' => [0x2a, 0x0b], '_' => [0x2a, 0x0c], '+' => [0x2a, 0x0d],
      '{' => [0x2a, 0x1a], '}' => [0x2a, 0x1b], ':' => [0x2a, 0x27],
      '"' => [0x2a, 0x28], '~' => [0x2a, 0x29], '|' => [0x2a, 0x2b],
      '?' => [0x2a, 0x35], '>' => [0x2a, 0x56],
    }
  )

  public_constant :US_KEYMAP
  public_constant :COMMON_KEYMAP
end

class Screen
  attr_reader :w, :h

  def initialize
    @w = 1024
    @h = 768
  end

  def xdotool(*args)
    out = cmd_helper(['xdotool'] + args.map(&:to_s))
    assert(out.empty?, "xdotool reported an error:\n" + out)
  end

  def match_screen(image, sensitivity, show_image)
    screenshot = "#{$config['TMPDIR']}/screenshot.png"
    $vm.display.screenshot(screenshot)
    OpenCV.matchTemplate("#{OPENCV_IMAGE_PATH}/#{image}",
                         screenshot, sensitivity, show_image)
  end

  def real_find(pattern, **opts)
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
    raise FindFailed, "cannot find #{image} on the screen" if p.nil?

    m = Match.new(image, self, *p)
    debug_log("Screen: found #{image} at (#{m.middle.join(', ')})")
    m
  end

  def wait(pattern, timeout, **opts)
    opts[:log] = true if opts[:log].nil?
    debug_log("Screen: waiting for #{pattern}") if opts[:log]
    try_for(timeout, delay: 0, log: false) do
      return real_find(pattern, **opts.clone.update(log: false))
    end
  rescue Timeout::Error
    raise FindFailed, "cannot find #{pattern} on the screen"
  end

  def find(pattern, **opts)
    debug_log("Screen: trying to find #{pattern}") if opts[:log]
    wait(pattern, 2, **opts.clone.update(log: false))
  end

  def exists(pattern, **opts)
    opts[:log] = true if opts[:log].nil?
    !find(pattern, **opts).nil?
  rescue FindFailed
    debug_log("cannot find #{pattern} on the screen") if opts[:log]
    false
  end

  def wait_vanish(pattern, timeout, **opts)
    opts[:log] = true if opts[:log].nil?
    debug_log("Screen: waiting for #{pattern} to vanish") if opts[:log]
    try_for(timeout, delay: 0, log: false) do
      !exists(pattern, **opts.clone.update(log: false))
    end
    debug_log("Screen: #{pattern} has vanished") if opts[:log]
    nil
  rescue Timeout::Error
    raise FindFailed, "can still find #{pattern} on the screen"
  end

  def find_any(patterns, **opts)
    opts[:log] = true if opts[:log].nil?
    if opts[:log]
      debug_log("Screen: trying to find any of #{patterns.join(', ')}")
    end
    patterns.each do |pattern|
      begin
        return [pattern, find(pattern, **opts.clone.update(log: false))]
      rescue FindFailed
        # Ignore. We'll throw an appropriate exception after having
        # looped through all patterns and found none of them.
      end
    end
    # If we've reached this point, none of the patterns could be found.
    raise FindFailed,
          "can not find any of the patterns #{patterns} on the screen"
  end

  def exists_any(*args, **opts)
    !find_any(*args, **opts).nil?
  rescue FindFailed
    false
  end

  def wait_any(patterns, time, **opts)
    opts[:log] = true if opts[:log].nil?
    debug_log("Screen: waiting for any of #{patterns.join(', ')}") if opts[:log]
    try_for(time, delay: 0, log: false) do
      return find_any(patterns, **opts.clone.update(log: false))
    end
  rescue Timeout::Error
    raise FindFailed, "can not find any of the patterns #{patterns} " \
                      'on the screen'
  end

  def press(*sequence, **opts)
    opts[:log] = true if opts[:log].nil?
    # This is the minimum time (in seconds) between key presses;
    # repeatedly calling this method will ensure that key presses are
    # emitted with this minimum interval. This helps preventing
    # repeated calls interfering with each other.
    opts[:delay] ||= 0.060 # Sikuli used 60ms delay.
    # How long the key(s) are held (in seconds). With holdtime = 0
    # (like virsh does it) we have seen issues, in particular with key
    # modifiers like Shift bleeding over to subsequent invocations, so
    # e.g. type("A9f") actually results in "A(F" (with a US layout)
    # because the Shift wasn't released *immediately* after the "A".
    opts[:holdtime] ||= 0.010
    debug_log("Keyboard: pressing: #{sequence.join('+')}") if opts[:log]
    codes = []
    sequence.each do |key|
      keymap = $language.empty? ? Keymaps::US_KEYMAP : Keymaps::COMMON_KEYMAP
      # We use lower-case to make it easier to get the keycodes right.
      code = keymap[('A'..'Z').include?(key) ? key : key.downcase]
      if code.nil?
        err = "No key code defined for key '#{key}'"
        err += " in #{$language}" unless $language.empty?
        raise err
      end
      codes += code
    end
    $vm.domain.send_key(Libvirt::Domain::KEYCODE_SET_LINUX,
                        (opts[:holdtime] * 1000).to_i, codes)
    sleep(opts[:delay])
    nil
  end

  def type(*args)
    args.each do |arg|
      if arg.instance_of?(String)
        debug_log("Keyboard: typing: #{arg}")
        arg.each_char do |char|
          press(char, log: false)
        end
      elsif arg.instance_of?(Array)
        press(*arg)
      else
        raise("Unsupported type: #{arg.class}")
      end
    end
    nil
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
    xdotool('mousemove', '--sync', x, y)
    [x, y]
  end

  def hide_cursor
    hover(@w - 1, @h / 2)
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
    action = 'clicking'
    if opts[:repeat] == 2
      action = "double-#{action}"
    elsif opts[:repeat] > 2
      action = "#{action} (repeat: #{opts[:repeat]})"
    end
    button = { 1 => 'left', 2 => 'middle', 3 => 'right' }[opts[:button]]
    debug_log("Mouse: #{action} #{button} button at (#{x}, #{y})") if opts[:log]
    xdotool('click', '--repeat', opts[:repeat], opts[:button])
    [x, y]
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

  # XXX: giving up on a few worst offenders for now
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/BlockLength
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/PerceivedComplexity
  def interactive_image_bump(image, **opts)
    opts[:sensitivity] ||= OPENCV_MIN_SIMILARITY
    $interactive_image_bump_ignores ||= []
    raise ImageBumpFailed if $interactive_image_bump_ignores.include?(image)

    message = "Failed to find #{image}"
    notify_user(message)
    warn("Screen: #{message}, entering interactive image bumping mode")
    # Ring the ASCII bell for a helpful notification in most terminal
    # emulators.
    STDOUT.write "\a"
    loop do
      warn(
        "\n" \
        "a: Automatic bump\n" \
        "r: Retry image (pro tip: manually update the image first!)\n" \
        "i: Ignore this image for the remaining of the run\n" \
        "d: Debugging REPL\n" \
        'q: Abort (to the FindFailed exception)'
      )
      c = STDIN.getch
      case c
      when 'a'
        [0.80, 0.70, 0.60, 0.50, 0.40, 0.30].each do |sensitivity|
          warn "Trying with sensitivity #{sensitivity}..."
          p = @screen.match_screen(image, sensitivity, true)
          next unless p

          warn 'Found match! Accept? (y/n)'
          loop do
            c = STDIN.getch
            if c == 'y'
              FileUtils.cp("#{$config['TMPDIR']}/last_opencv_match.png",
                           "#{OPENCV_IMAGE_PATH}/#{image}")
              return p
            elsif ['n', 3.chr].include?(c) # Ctrl+C => 3
              break
            end
          end
          break if c == 3.chr # Ctrl+C => 3
        end
        warn 'Failed to automatically bump image'
      when 'r'
        p = @screen.match_screen(image, opts[:sensitivity], true)
        if p.nil?
          warn 'Failed to find image'
        else
          warn 'Found match! Accept? (y/n)'
          c = STDIN.getch
          return p if c == 'y'
        end
      when 'i'
        $interactive_image_bump_ignores << image
        raise ImageBumpFailed
      when 'q', 3.chr # Ctrl+C => 3
        raise ImageBumpFailed
      when 'd'
        binding.pry(quiet: true) # rubocop:disable Lint/Debugger
      end
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/BlockLength
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/MethodLength

  screen_methods = Screen.instance_methods - Object.instance_methods
  overrides = [:find, :exists, :wait, :find_any, :exists_any,
               :wait_any, :hover, :click,]
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
