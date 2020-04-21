class OpenCVInternalError < StandardError
end

module OpenCV
  if cmd_helper('lsb_release --short --codename').chomp == 'stretch'
    @python = 'python2.7'
  else
    @python = 'python3'
  end

  def self.matchTemplate(image, screen, sensitivity, show_match)
    assert(sensitivity < 1.0)
    # Do a deep-copy so we don't mess up the outer environment
    env = Hash[ENV]
    if ENV['USER_DISPLAY'].nil? || ENV['USER_DISPLAY'] == ''
      show_match = false
    else
      env['DISPLAY'] = ENV['USER_DISPLAY']
    end
    p = popen_wait(
      [env, @python, "#{GIT_DIR}/features/scripts/opencv_match_template.py",
       screen, image, sensitivity.to_s, show_match.to_s],
      err: [:child, :out]
    )
    out = p.readlines.join("\n")
    case $?.exitstatus
    when 0
      return out.chomp.split.map { |s| s.to_i }
    when 1
      return nil
    else
      raise OpenCVInternalError.new(out)
    end
  end
end
