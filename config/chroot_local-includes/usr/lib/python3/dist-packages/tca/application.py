#!/usr/bin/python3

import prctl
import logging
import gettext
from argparse import ArgumentParser

from tca.ui.main_window import TCAMainWindow
import tca.config
from tca.utils import recover_fd_from_parent, TorLauncherUtils, TorLauncherNetworkUtils
from tailslib.logutils import configure_logging

import gi

gi.require_version("GLib", "2.0")
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk  # noqa: E402


class TCAApplication:
    """main controller for TCA."""

    def __init__(self, args):
        self.log = logging.getLogger(self.__class__.__name__)
        self.config_buf, controller = recover_fd_from_parent()
        controller.authenticate(password=None)
        self.configurator = TorLauncherUtils(controller, self.config_buf)
        self.configurator.load_conf()
        self.netutils = TorLauncherNetworkUtils()
        self.args = args
        self.debug = args.debug

        self.mainwindow = TCAMainWindow(self)


def get_parser():
    p = ArgumentParser()
    p.add_argument("--debug", dest="debug", action="store_true", default=False)
    p.add_argument("--debug-statefile")
    p.add_argument(
        "--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"]
    )
    p.add_argument("--log-target", default="auto", choices=["auto", "stderr", "syslog"])
    p.add_argument("gtk_args", nargs="*")

    return p


if __name__ == "__main__":
    prctl.set_name('tca')  # this get set as syslog identity!
    args = get_parser().parse_args()

    log_conf = {"level": logging.DEBUG if args.debug else args.log_level}
    configure_logging(hint=args.log_target, **log_conf)
    # translatable is a really really noisy logger. set it to debug only if really needed
    logging.getLogger('translatable').setLevel(logging.INFO)

    _ = gettext.gettext
    GLib.set_prgname(tca.config.APPLICATION_TITLE)
    GLib.set_application_name(_(tca.config.APPLICATION_TITLE))
    Gtk.init(args.gtk_args)
    application = TCAApplication(args)
    Gtk.Window.set_default_icon_name(tca.config.APPLICATION_ICON_NAME)
    Gtk.main()
