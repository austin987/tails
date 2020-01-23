import logging
import pipes

import tailsgreeter.config
from tailsgreeter.settings.utils import read_settings, write_settings


class NetworkSetting(object):
    """Setting controlling how Tails connects to Tor"""

    NETCONF_DIRECT = "direct"
    NETCONF_OBSTACLE = "obstacle"
    NETCONF_DISABLED = "disabled"

    def __init__(self):
        self.value = self.NETCONF_DIRECT
        self.settings_file = tailsgreeter.config.network_setting_path

    def apply_to_upcoming_session(self):
        write_settings(self.settings_file, {
            'TAILS_NETCONF': pipes.quote(self.value),
        })
        logging.debug('network setting written to %s', self.settings_file)

    def load(self) -> bool:
        try:
            settings = read_settings(self.settings_file)
        except FileNotFoundError:
            logging.debug("No persistent network settings file found (path: %s)", self.settings_file)
            return False

        value = settings.get('TAILS_NETCONF')
        if value:
            self.value = value
            logging.debug("Loaded network setting '%s'", value)
            return True
