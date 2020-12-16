#!/usr/bin/env python3

import cv2
import os
import sys
import traceback
from PIL import Image

class FindFailed(RuntimeError):
    pass

def match(image, candidate, sensitivity, show_match=False):
    """
    Returns the pos of candidate inside image, or raises if no match
    """
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
    cv2.imwrite(os.environ.get('TMPDIR', '/tmp') + '/last_opencv_match.png',
                image_rgb[y:y+h, x:x+w])
    if show_match:
        cv2.rectangle(image_rgb, pos, (x + w, y + h), (0, 0, 255), 1)
        cv2.imshow('Found match!', image_rgb)
        cv2.waitKey(0)
    return [x, y, w, h]

def main():
    try:
        try:
            sensitivity = float(sys.argv[3])
        except IndexError:
            sensitivity = 0.9
        try:
            show_match = sys.argv[4] == 'true'
        except IndexError:
            show_match = False
        print(*match(sys.argv[1], sys.argv[2],
                     sensitivity, show_match))
    except FindFailed:
        sys.exit(1)
    except IndexError:
        print("error: first argument must be the screen and the second the " +
              "image to find inside the screen", file=sys.stderr)
        sys.exit(2)
    except:
        traceback.print_exc()
        sys.exit(127)

if __name__ == "__main__":
    main()
