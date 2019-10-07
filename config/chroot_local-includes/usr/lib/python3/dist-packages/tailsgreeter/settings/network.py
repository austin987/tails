import os
import logging
import pipes

import tailsgreeter.config


class NetworkSetting(object):
    """Setting controlling how Tails connects to Tor"""

    NETCONF_DIRECT = "direct"
    NETCONF_OBSTACLE = "obstacle"
    NETCONF_DISABLED = "disabled"

    def __init__(self):
        self.value = self.NETCONF_DIRECT

    def apply_to_upcoming_session(self):
        setting_file = tailsgreeter.config.network_setting
        with open(setting_file, 'w') as f:
            os.chmod(setting_file, 0o600)
            f.write("TAILS_NETCONF=%s\n" % pipes.quote(self.value))
        logging.debug('network setting written to %s', setting_file)
