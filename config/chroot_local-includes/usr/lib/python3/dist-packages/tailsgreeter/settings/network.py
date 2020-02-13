import logging

import tailsgreeter.config
from tailsgreeter.settings.utils import read_settings, write_settings
from tailsgreeter.settings import SettingNotFoundError

NETCONF_DIRECT = "direct"
NETCONF_OBSTACLE = "obstacle"
NETCONF_DISABLED = "disabled"


class NetworkSetting(object):
    """Setting controlling how Tails connects to Tor"""

    def __init__(self):
        self.settings_file = tailsgreeter.config.network_setting_path

    def save(self, value: str):
        write_settings(self.settings_file, {
            'TAILS_NETCONF': value,
        })
        logging.debug('network setting written to %s', self.settings_file)

    def load(self) -> str:
        try:
            settings = read_settings(self.settings_file)
        except FileNotFoundError:
            raise SettingNotFoundError("No persistent network settings file found (path: %s)" % self.settings_file)

        value = settings.get('TAILS_NETCONF')
        if value is None:
            raise SettingNotFoundError("No network setting found in settings file (path: %s)", self.settings_file)

        logging.debug("Loaded network setting '%s'", value)
        return value
