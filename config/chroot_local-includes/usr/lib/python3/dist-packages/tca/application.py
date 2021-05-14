#!/usr/bin/python3

import os
import sys
import logging
import gettext
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from pathlib import Path
from typing import Optional, Dict, Any

from stem.control import Controller
import prctl
import gi
import dbus
import dbus.mainloop.glib
import systemd.daemon

from tca.ui.main_window import TCAMainWindow
import tca.config
from tca.torutils import (
    recover_fd_from_parent,
    TorLauncherUtils,
    TorLauncherNetworkUtils,
)
from tca.ui.asyncutils import GJsonRpcClient
from tailslib.logutils import configure_logging


gi.require_version("GLib", "2.0")
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk, Gio  # noqa: E402


dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

TOR_HAS_BOOTSTRAPPED_PATH = Path("/run/tor-has-bootstrapped/done")


class TCAApplication(Gtk.Application):
    """main controller for TCA."""

    def __init__(self, args):
        super().__init__(
            application_id="org.boum.tails.tor-connection-assistant",
            flags=Gio.ApplicationFlags.FLAGS_NONE,
        )
        self.log = logging.getLogger(self.__class__.__name__)
        self.config_buf, portal_sock = recover_fd_from_parent()
        self.controller = controller = Controller.from_port(port=9051)
        controller.authenticate(password=None)
        self.configurator = TorLauncherUtils(controller, self.config_buf)
        self.configurator.load_conf()
        self.portal = GJsonRpcClient(portal_sock)
        self.portal.connect("response-error", self.on_portal_error)
        self.portal.connect("response", self.on_portal_response)
        self.portal.run()
        self.netutils = TorLauncherNetworkUtils()
        self.args = args
        self.debug = args.debug
        self.window = None
        self.sys_dbus = dbus.SystemBus()
        self.last_nm_state = None
        self._tor_is_working: bool = TOR_HAS_BOOTSTRAPPED_PATH.exists()
        self.tor_info: Dict[str, Any] = {"DisableNetwork": None}

    def do_monitor_tor_is_working(self):
        # init tor-ready monitoring
        f = Gio.File.new_for_path(str(TOR_HAS_BOOTSTRAPPED_PATH))
        monitor = f.monitor(Gio.FileMonitorFlags.NONE, None)
        self._tor_is_working_monitor = monitor  # otherwise it will get GC'ed
        monitor.connect("changed", self.check_tor_is_working)

        return False

    def check_tor_is_working(self, monitor, _file, otherfile, event):
        if event == Gio.FileMonitorEvent.CREATED:
            self._tor_is_working = True
        elif event == Gio.FileMonitorEvent.DELETED:
            self._tor_is_working = False
        else:
            return
        self.log.info("tor_is_working = %s", self._tor_is_working)
        GLib.idle_add(self.window.on_tor_working_changed, self.is_tor_working)

    def check_tor_state(self, repeat: bool):
        # this is called periodically
        # XXX: change with proper notification handling from tor daemon itself
        changed = set()
        for infokey in ["DisableNetwork"]:
            resp = self.controller.get_conf(infokey)
            if resp is None:
                self.log.warn("No response from tor (asking %s)", infokey)
            else:
                if self.tor_info[infokey] != resp:
                    changed.add(infokey)
                self.tor_info[infokey] = resp

        if changed:
            self.log.info("tor state changed: %s", ",".join(changed))
            if hasattr(self.window, 'on_tor_state_changed'):
                GLib.idle_add(self.window.on_tor_state_changed, self.tor_info, changed)

        return repeat

    @property
    def is_tor_working(self) -> bool:
        return bool(self._tor_is_working)

    @property
    def is_network_link_ok(self) -> bool:
        return self.last_nm_state is not None and self.last_nm_state >= 60

    def on_portal_response(self, portal, unique_id, result):
        self.log.debug("response<%d> from portal : %s", unique_id, result)

    def on_portal_error(self, portal, unique_id, error):
        self.log.error("response-error<%d> from portal : %s", unique_id, error)

    def cb_dbus_nm_state(self, val):
        self.log.debug("NetworkManager state is now: %d", int(val))
        changed = False
        if self.last_nm_state != val:
            changed = True

        self.last_nm_state = val

        def wait_window():
            if self.window is None:
                return True
            GLib.idle_add(self.window.on_network_changed)
            return False

        if changed:
            if self.window is not None:
                GLib.idle_add(self.window.on_network_changed)
            else:
                GLib.timeout_add(100, wait_window)

    def do_startup(self):
        Gtk.Application.do_startup(self)

        action = Gio.SimpleAction.new("quit", None)
        action.connect("activate", self.on_quit)
        self.add_action(action)

        # one time only
        GLib.timeout_add(1, self.do_fetch_nm_state)
        GLib.timeout_add(1, self.do_monitor_tor_is_working)
        GLib.timeout_add(1, self.check_tor_state, False)

        # timers
        GLib.timeout_add(1000, self.check_tor_state, True)

        try:
            systemd.daemon.notify("READY=1")
        except OSError:  # not run as a systemd service
            pass

    def do_fetch_nm_state(self):
        def handle_hello_error(*args, **kwargs):
            self.log.warn("Error getting information from NetworkManager")
            self.last_nm_state = None

        nm_obj = self.sys_dbus.get_object(
            "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager"
        )
        nm = dbus.Interface(nm_obj, "org.freedesktop.NetworkManager")

        # get immediately
        nm.state(reply_handler=self.cb_dbus_nm_state, error_handler=handle_hello_error)
        # subscribe for changes
        nm.connect_to_signal("StateChanged", self.cb_dbus_nm_state)

        return False

    def do_activate(self):
        # We only allow a single window and raise any existing ones
        if self.window is None:
            # Windows are associated with the application
            # when the last one is closed the application shuts down
            self.window = TCAMainWindow(self)

        self.window.show()

    def on_quit(self, action, param):
        self.full_quit()

    def full_quit(self):
        try:
            systemd.daemon.notify("STOPPING=1")
        except OSError:  # not run as a systemd service
            pass
        self.quit()


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
    configure_logging(hint=args.log_target, ident="tca", **log_conf)
    # stem is a really really noisy logger. set it to debug only if really needed
    logging.getLogger("stem").setLevel(logging.DEBUG)

    _ = gettext.gettext
    GLib.set_prgname(tca.config.APPLICATION_TITLE)
    GLib.set_application_name(_(tca.config.APPLICATION_TITLE))

    application = TCAApplication(args)
    application.run([sys.argv[0]])
