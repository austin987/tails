#!/usr/bin/python3

import logging
import gettext
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter

from stem.control import Controller
import prctl
import gi

from tca.ui.main_window import TCAMainWindow
import tca.config
from tca.utils import recover_fd_from_parent, TorLauncherUtils, TorLauncherNetworkUtils
from tailslib.logutils import configure_logging


gi.require_version("GLib", "2.0")
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk  # noqa: E402


class TCAApplication:
    """main controller for TCA."""

    def __init__(self, args):
        self.log = logging.getLogger(self.__class__.__name__)
        self.config_buf, = recover_fd_from_parent()
        controller = Controller.from_port(port=9051)
        controller.authenticate(password=None)
        self.configurator = TorLauncherUtils(controller, self.config_buf)
        self.configurator.load_conf()
        self.netutils = TorLauncherNetworkUtils()
        self.args = args
        self.debug = args.debug

        self.mainwindow = TCAMainWindow(self)


def is_tails_debug_mode() -> bool:
    """Return True IFF Tails is started with the debug flag."""
    with open("/proc/cmdline") as buf:
        flags = buf.read().split()
    return "debug" in flags


def get_parser():
    p = ArgumentParser(formatter_class=ArgumentDefaultsHelpFormatter)
    p.add_argument("--debug", dest="debug", action="store_true", default=False)
    p.add_argument("--debug-statefile")
    p.add_argument(
        "--log-level",
        default="DEBUG" if is_tails_debug_mode() else "INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Minimum log level to be displayed",
    )
    p.add_argument(
        "--log-target",
        default="auto",
        choices=["auto", "stderr", "syslog"],
        help="Where to send log to; 'auto' will pick syslog IF stderr is not a tty",
    )
    p.add_argument("gtk_args", nargs="*")

    return p


if __name__ == "__main__":
    prctl.set_name("tca")  # this get set as syslog identity!
    args = get_parser().parse_args()

    log_conf = {"level": logging.DEBUG if args.debug else args.log_level}
    configure_logging(hint=args.log_target, ident='tca', **log_conf)
    # translatable is a really really noisy logger. set it to debug only if really needed
    logging.getLogger("translatable").setLevel(logging.INFO)

    _ = gettext.gettext
    GLib.set_prgname(tca.config.APPLICATION_TITLE)
    GLib.set_application_name(_(tca.config.APPLICATION_TITLE))
    Gtk.init(args.gtk_args)
    application = TCAApplication(args)
    Gtk.Window.set_default_icon_name(tca.config.APPLICATION_ICON_NAME)
    Gtk.main()
