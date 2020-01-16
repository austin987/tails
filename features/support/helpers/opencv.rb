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
    code = <<EOF
#!/usr/bin/env python3
from __future__ import print_function

import cv2
import os
import sys
from PIL import Image

class FindFailed(RuntimeError):
    pass

# Returns the pos of candidate inside image, or raises if no match
def match(image, candidate, sensitivity, show_match=False):
    assert(sensitivity < 1.0)
    image_rgb = cv2.imread(image, 1)
    image_gray = cv2.cvtColor(image_rgb, cv2.COLOR_BGR2GRAY)
    template = cv2.imread(candidate, 0)
    w, h = template.shape[::-1]
    res = cv2.matchTemplate(image_gray, template, cv2.TM_CCOEFF_NORMED)
    _, val, _, pos = cv2.minMaxLoc(res)
    x, y = pos
    if val < sensitivity:
        raise FindFailed
    cv2.imwrite(os.environ['TMPDIR'] + '/last_opencv_match.png',
                image_rgb[y:y+h, x:x+w])
    if show_match:
        cv2.rectangle(image_rgb, pos, (x + w, y + h), (0, 0, 255), 1)
        cv2.imshow('Found match!', image_rgb)
        cv2.waitKey(0)
    return [x, y, w, h]

try:
    print(*match("#{screen}", "#{image}", #{sensitivity},
                 #{show_match.to_s.capitalize}))
except FindFailed:
    sys.exit(1)
except:
    sys.exit(127)
EOF
    p = IO.popen([env, @python, '-c', code], err: [:child, :out])
    out = p.readlines.join("\n")
    p.close
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
