#!/usr/bin/python3
#
# Copyright 2012-2019 Tails developers <tails@boum.org>
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

import gi
import logging

from tailsgreeter.gdmclient import GdmClient
from tailsgreeter.settings import localization
from tailsgreeter.settings.admin import AdminSetting
from tailsgreeter.settings.localization_settings import LocalisationSettings
from tailsgreeter.settings.macspoof import MacSpoofSetting
from tailsgreeter.settings.network import NetworkSetting
from tailsgreeter.settings.persistence import PersistenceSettings
from tailsgreeter.translatable_window import TranslatableWindow
from tailsgreeter.ui.additional_settings import AdminSettingUI, MACSpoofSettingUI, NetworkSettingUI
from tailsgreeter.ui.main_window import GreeterMainWindow
from tailsgreeter.ui.region_settings import LanguageSettingUI, KeyboardSettingUI, FormatsSettingUI
from tailsgreeter.ui.settings_collection import GreeterSettingsCollection

gi.require_version('Gio', '2.0')
gi.require_version("Gtk", "3.0")
from gi.repository import Gio, Gtk


class GreeterApplication(object):
    """Tails greeter main controller

    This class is the greeter dbus service"""

    def __init__(self):
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
        self.gdmclient = GdmClient(session_opened_cb=self.close_app)

        persistence = PersistenceSettings()
        self.localisationsettings = LocalisationSettings(
            usermanager_loaded_cb=self.usermanager_loaded,
            locale_selected_cb=self.on_language_changed
        )
        self.admin_setting = AdminSetting()
        self.network_setting = NetworkSetting()
        self.macspoof_setting = MacSpoofSetting()

        # Initialize the settings
        settings = GreeterSettingsCollection(
            LanguageSettingUI(self.localisationsettings.language),
            KeyboardSettingUI(self.localisationsettings.keyboard),
            FormatsSettingUI(self.localisationsettings.formats),
            AdminSettingUI(self.admin_setting),
            MACSpoofSettingUI(self.macspoof_setting),
            NetworkSettingUI(self.network_setting),
        )

        # Initialize main window
        self.mainwindow = GreeterMainWindow(self, persistence, settings)

        # Inhibit the session being marked as idle
        self.inhibit_idle()

    def translate_to(self, lang):
        """Translate all windows to target language"""
        TranslatableWindow.translate_all(lang)

    def login(self):
        """Login GDM to the server"""
        logging.debug("login called")

        # Apply settings
        self.localisationsettings.apply_to_upcoming_session()
        self.admin_setting.apply_to_upcoming_session()
        self.macspoof_setting.apply_to_upcoming_session()
        self.network_setting.apply_to_upcoming_session()

        self.mainwindow.hide()
        self.gdmclient.do_login()

    def usermanager_loaded(self):
        """UserManager is ready"""
        logging.debug("Entering usermanager_loaded")
        self.ready = True
        logging.info("tails-greeter is ready.")
        self.mainwindow.show()

    def on_language_changed(self, locale_code: str):
        """Translate to the given locale"""
        self.localisationsettings.formats.on_language_changed(locale_code)  # XXX: notify
        self.localisationsettings.keyboard.on_language_changed(locale_code)  # XXX: notify
        self.translate_to(locale_code)
        self.mainwindow.current_language = localization.language_from_locale(locale_code)

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
