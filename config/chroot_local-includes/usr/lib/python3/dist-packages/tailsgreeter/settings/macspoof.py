import os
import logging
import pipes

import tailsgreeter.config


class MacSpoofSetting(object):
    """Setting controlling whether the MAC address is spoofed or not"""

    def __init__(self):
        self.value = True

    def apply_to_upcoming_session(self):
        setting_file = tailsgreeter.config.macspoof_setting
        with open(setting_file, 'w') as f:
            os.chmod(setting_file, 0o600)
            f.write("TAILS_MACSPOOF_ENABLED=%s\n" % pipes.quote(str(self.value)).lower())
        logging.debug('macspoof setting written to %s', setting_file)
