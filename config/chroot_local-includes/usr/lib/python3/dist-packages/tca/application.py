#!/usr/bin/python3

import logging
import gettext
import sys
from argparse import ArgumentParser

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

    def __init__(self, args):
        conf, controller = recover_fd_from_parent()
        controller.authenticate(password=None)
        self.configurator = TorLauncherUtils(controller, conf)
        self.configurator.load_conf()
        self.netutils = TorLauncherNetworkUtils()
        print(self.configurator.tor_connection_config.to_tor_conf())
        self.args = args
        self.debug = args.debug

        self.mainwindow = TCAMainWindow(self)


def get_parser():
    p = ArgumentParser()
    p.add_argument('--debug', dest='debug' , action='store_true', default=False)
    p.add_argument('--debug-statefile')
    p.add_argument('--log-level', default='INFO', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'])
    p.add_argument('gtk_args', nargs='*')
    
    return p


if __name__ == "__main__":
    args = get_parser().parse_args()
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=args.log_level)
    _ = gettext.gettext
    GLib.set_prgname(tca.config.APPLICATION_TITLE)
    GLib.set_application_name(_(tca.config.APPLICATION_TITLE))
    Gtk.init(args.gtk_args)
    application = TCAApplication(args)
    Gtk.Window.set_default_icon_name(tca.config.APPLICATION_ICON_NAME)
    Gtk.main()
