#!/usr/bin/python3

import logging
import gettext
import sys

from tca.ui.main_window import TCAMainWindow
import tca.config
from tca.utils import recover_fd_from_parent, TorLauncherUtils, TorLauncherNetworkUtils

import gi

gi.require_version("GLib", "2.0")
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk  # noqa: E402


class TCAApplication:
    """
    main controller
    """

    def __init__(self):
        conf, controller = recover_fd_from_parent()
        controller.authenticate(password=None)
        self.configurator = TorLauncherUtils(controller, conf)
        self.configurator.load_conf()
        self.netutils = TorLauncherNetworkUtils()
        print(self.configurator.tor_connection_config.to_tor_conf())
        self.mainwindow = TCAMainWindow(self)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    _ = gettext.gettext
    GLib.set_prgname(tca.config.APPLICATION_TITLE)
    GLib.set_application_name(_(tca.config.APPLICATION_TITLE))
    Gtk.init(sys.argv)
    application = TCAApplication()
    Gtk.Window.set_default_icon_name(tca.config.APPLICATION_ICON_NAME)
    Gtk.main()
