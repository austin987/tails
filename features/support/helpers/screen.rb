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

  def match_screen(image, sensitivity)
    screenshot = "#{$config["TMPDIR"]}/screenshot.png"
    $vm.display.screenshot(screenshot)
    return OpenCV.matchTemplate("#{OPENCV_IMAGE_PATH}/#{image}",
                                screenshot, sensitivity)
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
    p = match_screen(image, opts[:sensitivity])
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
