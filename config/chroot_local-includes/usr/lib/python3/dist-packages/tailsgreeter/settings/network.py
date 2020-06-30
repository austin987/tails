import tailsgreeter.config
from tailsgreeter.settings.setting import StringSetting

NETCONF_DIRECT = "direct"
NETCONF_OBSTACLE = "obstacle"
NETCONF_DISABLED = "disabled"


class NetworkSetting(StringSetting):
    """Setting controlling how Tails connects to Tor"""

    def __init__(self):
        super().__init__(tailsgreeter.config.network_setting_path, "TAILS_NETCONF")

