import logging

import tailsgreeter.config
from tailsgreeter.settings.utils import read_settings, write_settings


class MacSpoofSetting(object):
    """Setting controlling whether the MAC address is spoofed or not"""

    def __init__(self):
        self.settings_file = tailsgreeter.config.macspoof_setting_path

    def save(self, value: bool):
        write_settings(self.settings_file, {
            'TAILS_MACSPOOF_ENABLED': value,
        })
        logging.debug('macspoof setting written to %s', self.settings_file)

    def load(self) -> {bool, None}:
        try:
            settings = read_settings(self.settings_file)
        except FileNotFoundError:
            logging.debug("No persistent macspoof settings file found (path: %s)", self.settings_file)
            return None

        value_str = settings.get('TAILS_MACSPOOF_ENABLED')
        if value_str is None:
            logging.debug("No macspoof setting found in settings file (path: %s)", self.settings_file)
            return None
        value = value_str == "true"
        logging.debug("Loaded macspoof setting '%s'", value)
        return value
