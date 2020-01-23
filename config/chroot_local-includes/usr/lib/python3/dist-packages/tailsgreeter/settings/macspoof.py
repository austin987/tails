import logging
import pipes

import tailsgreeter.config
from tailsgreeter.settings.utils import read_settings, write_settings


class MacSpoofSetting(object):
    """Setting controlling whether the MAC address is spoofed or not"""

    def __init__(self):
        self.value = True
        self.settings_file = tailsgreeter.config.macspoof_setting_path

    def apply_to_upcoming_session(self):
        write_settings(self.settings_file, {
            'TAILS_MACSPOOF_ENABLED': pipes.quote(str(self.value)).lower(),
        })
        logging.debug('macspoof setting written to %s', self.settings_file)

    def load(self) -> bool:
        try:
            settings = read_settings(self.settings_file)
        except FileNotFoundError:
            logging.debug("No persistent macspoof settings file found (path: %s)", self.settings_file)
            return False

        value = settings.get('TAILS_MACSPOOF_ENABLED') == "true"
        if value:
            self.value = value
            logging.debug("Loaded macspoof setting '%s'", value)
            return True
