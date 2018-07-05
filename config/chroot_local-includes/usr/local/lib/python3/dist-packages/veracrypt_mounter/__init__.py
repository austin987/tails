# Translation stuff

import os
import gettext

from .config import APP_NAME


if os.path.exists('po/locale'):
    translation = gettext.translation(APP_NAME, 'po/locale', fallback=True)
else:
    translation = gettext.translation(APP_NAME, '/usr/share/locale', fallback=True)

_ = translation.gettext
