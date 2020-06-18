import logging

import tailsgreeter.config
from tailsgreeter.settings import SettingNotFoundError
from tailsgreeter.settings.utils import read_settings, write_settings


class UnsafeBrowserSetting(object):
    """Setting controlling whether the Unsafe Browser is available or not"""

    def __init__(self):
        self.settings_file = tailsgreeter.config.unsafe_browser_setting_path

    def save(self, value: bool):
        write_settings(self.settings_file, {
            'TAILS_UNSAFE_BROWSER_ENABLED': value,
        })
        logging.debug('unsafe-browser setting written to %s', self.settings_file)

    def load(self) -> bool:
        try:
            settings = read_settings(self.settings_file)
        except FileNotFoundError:
            raise SettingNotFoundError("No persistent unsafe-browser settings file found (path: %s)" % self.settings_file)

        value_str = settings.get('TAILS_UNSAFE_BROWSER_ENABLED')
        if value_str is None:
            raise SettingNotFoundError("No unsafe-browser setting found in settings file (path: %s)" % self.settings_file)

        value = value_str == "true"
        logging.debug("Loaded unsafe-browser setting '%s'", value)
        return value
