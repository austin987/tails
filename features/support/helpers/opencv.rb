require 'English'

class OpenCVInternalError < StandardError
end

module OpenCV
  @python = if cmd_helper('lsb_release --short --codename').chomp == 'stretch'
              'python2.7'
            else
              'python3'
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
       screen, image, sensitivity.to_s, show_match.to_s,],
      err: [:child, :out]
    )
    out = p.readlines.join("\n")
    case $CHILD_STATUS.exitstatus
    when 0
      out.chomp.split.map(&:to_i)
    when 1
      nil
    else
      raise OpenCVInternalError, out
    end
  end
end
