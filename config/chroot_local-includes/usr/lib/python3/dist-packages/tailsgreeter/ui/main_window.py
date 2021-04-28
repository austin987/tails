# -*- coding: utf-8 -*-/
#
# Copyright 2015-2016 Tails developers <tails@boum.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>

import locale
import logging
from typing import TYPE_CHECKING
import gi
import glob
import os
import sh

import tailsgreeter                                             # NOQA: E402
import tailsgreeter.config                                      # NOQA: E402
from tailsgreeter.config import settings_dir, persistent_settings_dir, admin_password_path
import tailsgreeter.utils                                       # NOQA: E402
from tailsgreeter.settings import SettingNotFoundError
from tailsgreeter.translatable_window import TranslatableWindow
from tailsgreeter.ui.popover import Popover
from tailsgreeter.ui import _
from tailsgreeter.ui.add_settings_dialog import AddSettingsDialog
from tailsgreeter.ui.additional_settings import AdditionalSetting
from tailsgreeter.ui.help_window import GreeterHelpWindow
from tailsgreeter.ui.region_settings import LocalizationSettingUI
from tailsgreeter import TRANSLATION_DOMAIN
from tailsgreeter.ui.persistent_storage import PersistentStorage


gi.require_version('Gdk', '3.0')
gi.require_version('Gtk', '3.0')
from gi.repository import Gdk, Gtk

if TYPE_CHECKING:
    from tailsgreeter.settings.persistence import PersistenceSettings
    from tailsgreeter.ui.settings_collection import GreeterSettingsCollection


MAIN_UI_FILE = 'main.ui'
CSS_FILE = 'greeter.css'
ICON_DIR = 'icons/'
PREFERRED_WIDTH = 620
PREFERRED_HEIGHT = 470

locale.bindtextdomain(TRANSLATION_DOMAIN, tailsgreeter.config.system_locale_dir)


class GreeterMainWindow(Gtk.Window, TranslatableWindow):
    def __init__(self, greeter, persistence_setting: "PersistenceSettings", settings: "GreeterSettingsCollection"):
        Gtk.Window.__init__(self, title=_(tailsgreeter.APPLICATION_TITLE))
        TranslatableWindow.__init__(self, self)
        self.greeter = greeter
        self.persistence_setting = persistence_setting
        self.settings = settings
        self.current_language = "en"

        # Set the main_window attribute for the settings. This is required
        # in order to allow the settings to trigger changes in the main
        # window, for example showing an info bar.
        for setting in self.settings:
            setting.main_window = self

        self.connect('delete-event', self.cb_window_delete_event, None)
        self.set_position(Gtk.WindowPosition.CENTER)

        # Load custom CSS
        css_provider = Gtk.CssProvider()
        css_provider.load_from_path(tailsgreeter.config.data_path + CSS_FILE)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        # Load UI interface definition
        builder = Gtk.Builder()
        builder.set_translation_domain(TRANSLATION_DOMAIN)
        builder.add_from_file(tailsgreeter.config.data_path + MAIN_UI_FILE)
        builder.connect_signals(self)

        for widget in builder.get_objects():
            # Store translations for the builder objects
            self.store_translations(widget)
            # Workaround Gtk bug #710888 - GtkInfoBar not shown after calling
            # gtk_widget_show:
            # https://bugzilla.gnome.org/show_bug.cgi?id=710888
            if isinstance(widget, Gtk.InfoBar):
                revealer = widget.get_template_child(Gtk.InfoBar, 'revealer')
                revealer.set_transition_type(Gtk.RevealerTransitionType.NONE)

        self.box_language = builder.get_object('box_language')
        self.box_language_header = builder.get_object('box_language_header')
        self.box_main = builder.get_object('box_main')
        self.box_settings = builder.get_object('box_settings')
        self.box_settings_header = builder.get_object('box_settings_header')
        self.box_settings_values = builder.get_object('box_settings_values')
        self.box_storage = builder.get_object('box_storage')
        self.box_storage_unlock = builder.get_object('box_storage_unlock')
        self.box_storage_unlocked = builder.get_object('box_storage_unlocked')
        self.entry_storage_passphrase = builder.get_object('entry_storage_passphrase')
        self.frame_language = builder.get_object('frame_language')
        self.infobar_settings_loaded = builder.get_object('infobar_settings_loaded')
        self.label_settings_default = builder.get_object('label_settings_default')
        self.listbox_add_setting = builder.get_object('listbox_add_setting')
        self.listbox_settings = builder.get_object('listbox_settings')
        self.toolbutton_settings_add = builder.get_object('toolbutton_settings_add')
        self.listbox_settings = builder.get_object("listbox_settings")
        self.listbox_region = builder.get_object("listbox_region")
        self.button_start = builder.get_object("button_start")
        self.headerbar = builder.get_object("headerbar")

        # Set preferred width
        self.set_default_size(min(Gdk.Screen.get_default().get_width(),
                                  PREFERRED_WIDTH),
                              min(Gdk.Screen.get_default().get_height(),
                                  PREFERRED_HEIGHT))

        # Add our icon dir to icon theme
        icon_theme = Gtk.IconTheme.get_default()
        icon_theme.prepend_search_path(
            tailsgreeter.config.data_path + ICON_DIR)

        # Add placeholder to settings ListBox
        self.listbox_settings.set_placeholder(self.label_settings_default)

        # Persistent storage
        self.persistent_storage = PersistentStorage(self.persistence_setting, self.load_settings, self.apply_settings, builder)

        # Add children to ApplicationWindow
        self.add(self.box_main)
        self.set_titlebar(self.headerbar)

        # Set keyboard focus chain
        self._set_focus_chain()

        # Add settings to region listbox
        for setting in self.settings.region_settings:
            logging.debug("Adding '%s' to region listbox", setting.id)
            self.listbox_region.add(setting.listboxrow)

        # Add settings dialog
        self.dialog_add_setting = AddSettingsDialog(builder, self.settings)
        self.dialog_add_setting.set_transient_for(self)

        # Setup keyboard accelerators
        self._build_accelerators()

        self.store_translations(self)

    # Utility methods

    def _build_accelerators(self):
        accelgroup = Gtk.AccelGroup()
        self.add_accel_group(accelgroup)
        for accel_key in [s.accel_key for s in self.settings if s.accel_key]:
            accelgroup.connect(
                accel_key,
                Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK,
                Gtk.AccelFlags.VISIBLE,
                self.cb_accelgroup_setting_activated)

    def _set_focus_chain(self):
        self.box_language.set_focus_chain([
                self.frame_language,
                self.box_language_header])
        self.box_settings.set_focus_chain([
                self.box_settings_values,
                self.box_settings_header])

    # Actions

    def apply_settings(self):
        for setting in self.settings:
            setting.apply()

    def load_settings(self):
        # We have to load formats and keyboard before language, because
        # changing the language also changes the other two, which causes
        # the settings files to be overwritten. So we load the region
        # settings in reversed order.
        settings_loaded = False
        for setting in reversed(list(self.settings.region_settings)):
            try:
                changed = setting.load()
                if changed:
                    # We only want to show the "settings loaded" notification
                    # if settings were actually changed, i.e. the settings
                    # in the persistent settings dir were not the same as
                    # the already configured ones.
                    # Else, the notification would also be shown the first time
                    # the system is booted after creating the Persistent Storage
                    # (which currently means that the Persistent Storage is empty,
                    # but that's WIP on #11529), because then the persistent
                    # settings dir doesn't exist yet, which means that live-boot
                    # copies the current settings dir to the Persistent Storage -
                    # which contains the currently configured settings, which are
                    # then loaded.
                    settings_loaded = True
            except SettingNotFoundError as e:
                logging.debug(e)
                # The settings file does not exist, so we create it by
                # applying the setting's default value.
                setting.apply()

        for setting in self.settings.additional_settings:
            try:
                changed = setting.load()
                # We only add the setting to the list of additional settings
                # if it was actually changed. Else it is either already added or
                # it has the default value.
                if not changed:
                    continue
                settings_loaded = True
                # Add the setting to the listbox of added settings, if it was
                # not added before (by the user, before unlocking perrsistence).
                if self.setting_added(setting.id):
                    # The setting was already added, we only have to call apply()
                    # to update the label
                    setting.apply()
                else:
                    self.add_setting(setting.id)
            except SettingNotFoundError as e:
                logging.debug(e)
                # The settings file does not exist, so we create it by
                # applying the setting's default value.
                setting.apply()

        if settings_loaded:
            self.infobar_settings_loaded.set_visible(True)

    def run_add_setting_dialog(self, id_=None):
        response = self.dialog_add_setting.run(id_)
        if response == Gtk.ResponseType.YES:
            row = self.listbox_add_setting.get_selected_row()
            id_ = self.settings.id_from_row(row)
            setting = self.settings.additional_settings[id_]

            self.dialog_add_setting.set_visible(False)
            self.dialog_add_setting.stack.remove(setting.box)

            self.add_setting(id_)
        else:
            old_details = self.dialog_add_setting.stack.get_child_by_name(
                    'setting-details')
            if old_details:
                self.dialog_add_setting.stack.remove(old_details)
            self.dialog_add_setting.set_visible(False)

    def add_setting(self, id_):
        logging.debug("Adding setting '%s'", id_)
        setting = self.settings.additional_settings[id_]
        setting.apply()
        setting.build_popover()

        self.listbox_add_setting.remove(setting.listboxrow)
        self.listbox_settings.add(setting.listboxrow)
        self.listbox_settings.unselect_all()

        if not self.listbox_add_setting.get_children():
            self.toolbutton_settings_add.set_sensitive(False)

    def edit_setting(self, id_):
        if self.settings[id_].has_popover():
            self.settings[id_].listboxrow.emit("activate")
        else:
            self.run_add_setting_dialog(id_)

    def setting_added(self, id_):
        setting = self.settings.additional_settings[id_]
        return setting.listboxrow in self.listbox_settings.get_children()

    def show(self):
        super().show()
        self.button_start.grab_focus()
        self.get_root_window().set_cursor(Gdk.Cursor.new(Gdk.CursorType.ARROW))

    # Callbacks

    def cb_accelgroup_setting_activated(self, accel_group, accelerable,
                                        keyval, modifier):
        for setting in self.settings:
            if setting.accel_key == keyval:
                self.edit_setting(setting.id)
        return False

    def cb_linkbutton_help_activate(self, linkbutton, user_data=None):

        def localize_page(page: str) -> str:
            """Try to get a localized version of the page"""
            if self.current_language == "en":
                return page

            localized_page = page.replace(".en.", ".%s." % self.current_language)

            # Strip the fragment identifier
            index = localized_page.find('#')
            filename = localized_page[:index] if index > 0 else localized_page

            if os.path.isfile("/usr/share/doc/tails/website/" + filename):
                return localized_page
            return page

        linkbutton.set_sensitive(False)
        # Display progress cursor and update the UI
        self.get_window().set_cursor(Gdk.Cursor.new(Gdk.CursorType.WATCH))
        while Gtk.events_pending():
            Gtk.main_iteration()

        page = linkbutton.get_uri()
        page = localize_page(page)

        # Note that we add the "file://" part here, not in the URI.
        # We're forced to add this
        # callback *in addition* to the standard one (Gtk.show_uri),
        # which will do nothing for uri:s without a protocol
        # part. This is critical since we otherwise would open the
        # default browser (iceweasel) in T-G. If pygtk had a mechanism
        # like gtk's g_signal_handler_find() this could be dealt with
        # in a less messy way by just removing the default handler.
        uri = "file:///usr/share/doc/tails/website/" + page
        logging.debug("Opening help window for {}".format(uri))
        helpwindow = GreeterHelpWindow(uri)
        helpwindow.show()

        def restore_linkbutton_status(widget, event, linkbutton):
            linkbutton.set_sensitive(True)
            return False

        helpwindow.connect('delete-event', restore_linkbutton_status,
                           linkbutton)
        # Restore default cursor
        self.get_window().set_cursor(None)

    def cb_button_shutdown_clicked(self, widget, user_data=None):
        self.greeter.shutdown()
        return False

    def cb_button_start_clicked(self, widget, user_data=None):
        for setting in glob.glob(os.path.join(settings_dir, 'tails.*')):
            sh.cp("-a", setting, persistent_settings_dir)
        try:
            self.greeter.admin_setting.load()
        except SettingNotFoundError:
            # The admin password is not set, so we have to make sure that
            # the file also doesn't exist in the persistent directory,
            # in case that the user disabled a persisted admin password.
            pw_filename = os.path.basename(admin_password_path)
            sh.rm("-f", os.path.join(persistent_settings_dir, pw_filename))

        self.greeter.login()
        return False

    def cb_button_storage_unlock_clicked(self, widget, user_data=None):
        self.persistent_storage.unlock()
        return False

    def cb_entry_storage_passphrase_activated(self, entry, user_data=None):
        self.persistent_storage.unlock()
        return False

    def cb_entry_storage_passphrase_changed(self, editable, user_data=None):
        self.persistent_storage.passphrase_changed(editable)
        # Only allow starting if the password entry is empty. We used to
        # attempt unlocking with the entered password when the "Start Tails"
        # button was clicked, but changed that behavior (see #17136), so
        # we now force users to click the "Unlock" button first before
        # they can click "Start Tails".
        allow_start = not bool(editable.get_text())
        self.button_start.set_sensitive(allow_start)
        return False

    def cb_infobar_close(self, infobar, user_data=None):
        infobar.set_visible(False)
        return False

    def cb_infobar_response(self, infobar, response_id, user_data=None):
        infobar.set_visible(False)
        return False

    def cb_listbox_add_setting_focus(self, widget, direction, user_data=None):
        self.dialog_add_setting.listbox_focus()
        return False

    def cb_listbox_add_setting_row_activated(self, listbox, row, user_data=None):
        self.dialog_add_setting.listbox_row_activated(row)
        return False

    def cb_listbox_region_row_activated(self, listbox, row, user_data=None):
        setting = self.settings[self.settings.id_from_row(row)]
        if not setting.popover.is_open():
            setting.popover.open(self.on_region_setting_popover_closed, setting)
        return False

    def on_region_setting_popover_closed(self, popover: Popover, setting: LocalizationSettingUI):
        # Unselect the listbox row
        self.listbox_region.unselect_all()

        if popover.response != Gtk.ResponseType.YES:
            return

        setting.apply()

    def cb_listbox_settings_row_activated(self, listbox, row, user_data=None):
        setting = self.settings[self.settings.id_from_row(row)]
        if not setting.popover.is_open():
            setting.popover.open(self.on_additional_setting_popover_closed, setting)
        return False

    def on_additional_setting_popover_closed(self, popover: Popover, setting: AdditionalSetting):
        logging.debug("'%s' popover closed. response: %s", setting.id, popover.response)
        # Unselect the listbox row
        self.listbox_settings.unselect_all()
        if popover.response == Gtk.ResponseType.YES:
            setting.apply()

    def cb_toolbutton_settings_add_clicked(self, user_data=None):
        self.run_add_setting_dialog()
        return False

    def cb_toolbutton_settings_mnemonic_activate(self, widget, group_cycling):
        self.run_add_setting_dialog()
        return False

    def cb_window_delete_event(self, widget, event, user_data=None):
        # Don't close the toplevel window on user request (e.g. pressing
        # Alt+F4)
        return True


class GreeterBackgroundWindow(Gtk.ApplicationWindow):

    def __init__(self, app):
        super().__init__(app)
        Gtk.Window.__init__(self, title=_(tailsgreeter.APPLICATION_TITLE),
                            application=app)
        self.override_background_color(
                Gtk.StateFlags.NORMAL, Gdk.RGBA(0, 0, 0, 1))
