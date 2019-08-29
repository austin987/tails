#!/usr/bin/python3
#
# Copyright 2012-2016 Tails developers <tails@boum.org>
# Copyright 2011 Max <govnototalitarizm@gmail.com>
# Copyright 2011 Martin Owens
#
# This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#
"""
GDM greeter for Tails project using gtk
"""

import gettext
import locale
import logging
import logging.config
import sys
import traceback                                        # NOQA: F401


logging.config.fileConfig('tails-logging.conf')
# Set loglevel if debug is found in kernel command line
with open('/proc/cmdline') as cmdline_fd:
    cmdline = cmdline_fd.read()
if "debug" in cmdline.split():
    logging.getLogger().setLevel(logging.DEBUG)


def log_exc(etype, value, tb):
    for line in traceback.format_exception(etype, value, tb):
        print(line, file=sys.stderr)


sys.excepthook = log_exc


import gi                                               # NOQA: F401
gi.require_version('GLib', '2.0')
from gi.repository import GLib                          # NOQA: F401
from gi.repository import Gio                           # NOQA: F401
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk                           # NOQA: F401

import tailsgreeter                                     # NOQA: F401
import tailsgreeter.config                              # NOQA: F401
import tailsgreeter.gdmclient                           # NOQA: F401
import tailsgreeter.persistence                         # NOQA: F401
import tailsgreeter.physicalsecurity                    # NOQA: F401
import tailsgreeter.rootaccess                          # NOQA: F401

from tailsgreeter.language import TranslatableWindow    # NOQA: F401
from tailsgreeter.gui import GreeterMainWindow          # NOQA: F401

gettext.install(tailsgreeter.__appname__, tailsgreeter.config.locales_path)
locale.bindtextdomain(tailsgreeter.__appname__,
                      tailsgreeter.config.locales_path)


class GreeterApplication():
    """Tails greeter main controller

    This class is the greeter dbus service"""

    def __init__(self):
        self.language = 'en_US.UTF-8'
        self.session = None
        self.forced = False
        self.postponed = False
        self.postponed_text = None
        self.ready = False
        self.translated = False

        self._sessionmanager = Gio.DBusProxy.new_for_bus_sync(
                Gio.BusType.SESSION,
                Gio.DBusProxyFlags.NONE,
                None,
                "org.gnome.SessionManager",
                "/org/gnome/SessionManager",
                "org.gnome.SessionManager")

        # Load models
        self.gdmclient = tailsgreeter.gdmclient.GdmClient(
            session_opened_cb=self.close_app
        )
        self.persistence = tailsgreeter.persistence.PersistenceSettings()
        self.localisationsettings = tailsgreeter.language.LocalisationSettings(
            usermanager_loaded_cb=self.usermanager_loaded,
            locale_selected_cb=self.locale_selected
        )
        self.rootaccess = \
            tailsgreeter.rootaccess.RootAccessSettings()
        self.physical_security = \
            tailsgreeter.physicalsecurity.PhysicalSecuritySettings()

        # Load views
        self.mainwindow = GreeterMainWindow(self)

        # Inhibit the session being marked as idle
        self.inhibit_idle()

    def translate_to(self, lang):
        """Translate all windows to target language"""
        TranslatableWindow.translate_all(lang)

    def login(self):
        """Login GDM to the server"""
        logging.debug("login called")
        self.mainwindow.hide()
        self.gdmclient.do_login()

    def usermanager_loaded(self):
        """UserManager is ready"""
        logging.debug("Entering usermanager_loaded")
        self.ready = True
        self.localisationsettings.text.set_value('en_US')
        logging.info("tails-greeter is ready.")
        self.mainwindow.show()

    def locale_selected(self, locale_code):
        """Translate to the given locale"""
        self.translate_to(locale_code)

    def close_app(self):
        """We're done, quit gtk app"""
        logging.info("Finished.")
        Gtk.main_quit()

    def shutdown(self):
        """Shuts down the computer using GNOME Session Manager"""
        logging.info("Shutdown")
        self._sessionmanager.Shutdown()

    def inhibit_idle(self):
        cookie = self._sessionmanager.Inhibit(
                "(susu)",
                "org.boum.tails.Greeter",
                0,
                "Greeter session shouldn't idle",
                8)  # Inhibit the session being marked as idle
        logging.debug("inhibitor cookie=%i", cookie)


if __name__ == "__main__":
    GLib.set_prgname(tailsgreeter.APPLICATION_TITLE)
    GLib.set_application_name(
            _(tailsgreeter.APPLICATION_TITLE))          # NOQA: F821
    Gtk.init(sys.argv)
    Gtk.Window.set_default_icon_name(tailsgreeter.APPLICATION_ICON_NAME)

    application = GreeterApplication()
    Gtk.main()
