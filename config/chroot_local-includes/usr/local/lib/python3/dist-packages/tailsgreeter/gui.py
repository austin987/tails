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
import threading
import webbrowser

import gi

gi.require_version('GLib', '2.0')
from gi.repository import GLib                                  # NOQA: E402
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk                                   # NOQA: E402
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk                                   # NOQA: E402
gi.require_version('Pango', '1.0')
from gi.repository import Pango                                 # NOQA: E402
gi.require_version('WebKit2', '4.0')
from gi.repository import WebKit2                               # NOQA: E402

import tailsgreeter                                             # NOQA: E402
import tailsgreeter.config                                      # NOQA: E402
import tailsgreeter.utils                                       # NOQA: E402
from tailsgreeter.language import TranslatableWindow            # NOQA: E402

from tailsgreeter import TRANSLATION_DOMAIN

UI_FILE = 'greeter.ui'
CSS_FILE = 'greeter.css'
ICON_DIR = 'icons/'
MAIN_WINDOW_PREFERRED_WIDTH = 620
MAIN_WINDOW_PREFERRED_HEIGHT = 470
ADD_SETTING_DIALOG_PREFERRED_WIDTH = 400
HELP_WINDOW_PREFERRED_WIDTH = 800

locale.bindtextdomain(TRANSLATION_DOMAIN, tailsgreeter.config.locales_path)
# Mark translatable strings, but don't actually translate them, as we
# delegate this to TranslatableWindow that handles on-the-fly language changes
_ = lambda text: text   # NOQA: E731


class GreeterSetting(object):
    def __init__(self, setting_id):
        self.setting_id = setting_id
        self.listbox_container = None
        self.accel_key = None

    def cb_popover_closed(self, popover, user_data=None):
        self.listbox_container.unselect_all()
        return False

    @staticmethod
    def _add_popover(widget, content, closed_cb=None):
        popover = Gtk.Popover.new(widget)
        popover.set_position(Gtk.PositionType.BOTTOM)
        popover.add(content)
        if closed_cb:
            popover.connect('closed', closed_cb)
        return popover

    @staticmethod
    def _fill_tree_view(name, treeview):
        assert isinstance(name, str)
        assert isinstance(treeview, Gtk.TreeView)
        renderer = Gtk.CellRendererText()
        renderer.props.ellipsize = Pango.EllipsizeMode.END
        column = Gtk.TreeViewColumn(name, renderer, text=1)
        treeview.append_column(column)


class RegionSetting(GreeterSetting):
    def __init__(self, setting_id, greeter, builder, setting_target=None):
        super().__init__(setting_id)
        self.greeter = greeter

        if not setting_target:
            setting_target = setting_id
        self.target = setting_target

        self.target.connect("notify::value", self.cb_value_changed)

        self.treestore = self.target.get_tree()
        self.build_ui(builder)

    def build_ui(self, builder):
        self.listbox_container = builder.get_object("listbox_language")

        listboxrow = builder.get_object(
                "listboxrow_{}".format(self.setting_id))
        self.label_value = builder.get_object(
                "label_{}_value".format(self.setting_id))
        box = builder.get_object(
                "box_{}_popover".format(self.setting_id))
        self.treeview = builder.get_object(
                "treeview_{}".format(self.setting_id))
        searchentry = builder.get_object(
                "searchentry_{}".format(self.setting_id))

        self.popover = GreeterSetting._add_popover(
                listboxrow, box, closed_cb=self.cb_popover_closed)

        GreeterSetting._fill_tree_view("", self.treeview)
        self.treestore_filtered = self.treestore.filter_new()
        self.treestore_filtered.set_visible_func(
                self.cb_liststore_filtered_visible_func, data=searchentry)
        self.treeview.set_model(self.treestore_filtered)

        searchentry.connect("search-changed",
                            self.cb_searchentry_search_changed)
        searchentry.connect("activate", self.cb_searchentry_activate)
        self.treeview.connect("row-activated", self.cb_treeview_row_activated)

    def cb_searchentry_activate(self, searchentry, user_data=None):
        """Selects the topmost item in the treeview when pressing Enter"""
        if searchentry.get_text():
            self.treeview.row_activated(Gtk.TreePath.new_from_string("0"),
                                        self.treeview.get_column(0))
        else:
            self.popover.set_visible(False)

    def cb_searchentry_search_changed(self, searchentry, user_data=None):
        self.treestore_filtered.refilter()
        if searchentry.get_text():
            self.treeview.expand_all()
            self.treeview.scroll_to_point(0, 0)  # scroll to top
        else:
            self.treeview.collapse_all()
        return False

    def cb_treeview_row_activated(self, treeview, path, column,
                                  user_data=None):
        treemodel = treeview.get_model()
        code = treemodel.get_value(treemodel.get_iter(path), 0)
        name = treemodel.get_value(treemodel.get_iter(path), 1)

        self.label_value.set_label(name)
        self.popover.set_visible(False)

        self.target.set_value(code)

    def cb_value_changed(self, obj, param):
        logging.debug("refreshing {}".format(self.target))
        self.label_value.set_label(self.target.get_name())

        def treeview_select_line(model, path, iter, data):
            if model.get_value(iter, 0) == data:
                self.treeview.get_selection().select_iter(iter)
                self.treeview.scroll_to_cell(path, use_align=True,
                                             row_align=0.5)
                return True
            else:
                return False

        self.treestore_filtered.foreach(
                treeview_select_line,
                self.target.get_value())

    def cb_liststore_filtered_visible_func(self, model, treeiter, searchentry):
        search_query = searchentry.get_text().lower()
        if not search_query:
            return True

        # Does the current node match the search?
        value = model.get_value(treeiter, 1).lower()
        if search_query in value:
            return True

        # Does the parent node match the search?
        treepath = model.get_path(treeiter)
        parent_treepath = treepath.copy()
        parent_treepath.up()
        if parent_treepath.get_depth() == 1:
            # treepath is now the parent
            parent_value = model.get_value(model.get_iter(parent_treepath), 0)
            return search_query in parent_value

        # Does any of the children nodes match the search?
        children_treeiter = model.iter_children(treeiter)
        while children_treeiter:
            child_value = model.get_value(children_treeiter, 0)
            if search_query in child_value:
                return True
            children_treeiter = model.iter_next(children_treeiter)

        return False


class TextSetting(RegionSetting):
    def __init__(self, greeter, builder):
        super().__init__("text", greeter, builder,
                         greeter.localisationsettings.text)


class KeyboardSetting(RegionSetting):
    def __init__(self, greeter, builder):
        super().__init__("keyboard", greeter, builder,
                         greeter.localisationsettings.layout)


class FormatsSetting(RegionSetting):
    def __init__(self, greeter, builder):
        super().__init__("formats", greeter, builder,
                         greeter.localisationsettings.formats)


class TimezoneSetting(RegionSetting):
    def __init__(self, greeter, builder):
        super().__init__("tz", greeter, builder,
                         greeter.localisationsettings.timezone)


class AdditionalSetting(GreeterSetting):
    def __init__(self, setting_id, greeter, builder):
        super().__init__(setting_id)
        self.greeter = greeter
        self.build_ui(builder)

    def build_ui(self, builder):
        self.listbox_container = builder.get_object("listbox_settings")

        self.listboxrow = builder.get_object(
                "listboxrow_{}".format(self.setting_id))
        self.label_value = builder.get_object(
                "label_{}_value".format(self.setting_id))
        self.box = builder.get_object(
                "box_{}_popover".format(self.setting_id))

    def build_popover(self):
        self.popover = GreeterSetting._add_popover(
                self.listboxrow, self.box, closed_cb=self.cb_popover_closed)

        return self.popover

    def close_popover_if_any(self):
        """Closes the popover if it exists

        Returns True if the popover was closed, False if there is no popover"""
        if self.has_popover():
            self.popover.set_visible(False)
            return True
        else:
            return False

    def has_popover(self):
        return hasattr(self, 'popover')


class AdminSetting(AdditionalSetting):
    def __init__(self, greeter, builder):
        super().__init__("admin", greeter, builder)
        self.accel_key = Gdk.KEY_a

    def build_ui(self, builder):
        super().build_ui(builder)
        tailsgreeter.utils.import_builder_objects(self, builder, [
                'box_admin_password',
                'box_admin_verify',
                'button_admin_disable',
                'entry_admin_password',
                'entry_admin_verify',
                'label_admin_value',
                ])

    # XXX-non-blocker: avoid mixing business logic with GUI code?
    # The "check and return a boolean" operation should live in a pure function
    # outside of this file, and a method here should use it to update the GUI
    # accordingly.
    def check(self):
        password = self.entry_admin_password.get_text()
        verify = self.entry_admin_verify.get_text()
        if verify and verify == password:
            icon = 'emblem-ok-symbolic'
        elif verify and not (verify == password):
            icon = 'dialog-warning-symbolic'
        else:
            icon = None
        self.entry_admin_verify.set_icon_from_icon_name(
                    Gtk.EntryIconPosition.SECONDARY, icon)
        return (verify == password)

    def apply(self):
        if self.check():
            password = self.entry_admin_password.get_text()
            self.greeter.rootaccess.password = password
            # XXX-non-blocker: the action at a distance on next line is
            # scary; better return the admin password (or False if the check
            # fails), and let the caller modify its own state... or do some
            # slightly less scary action at a distance?
            # Same comment wrt. the disable method, and more
            # generally it feels wrong that each *Setting objects gets a
            # greeter attribute they can mess with as they want.
            self.label_admin_value.set_label(
                tailsgreeter.utils.get_on_off_string(password, default=None))
            self.box_admin_password.set_visible(False)
            self.box_admin_verify.set_visible(False)
            self.button_admin_disable.set_visible(True)
            return True
        else:
            return False

    def disable(self):
        self.greeter.rootaccess.password = None
        self.label_admin_value.set_label(
                tailsgreeter.utils.get_on_off_string(None, default=None))
        self.entry_admin_password.set_text("")
        self.entry_admin_verify.set_text("")
        self.box_admin_password.set_visible(True)
        self.box_admin_verify.set_visible(True)
        self.button_admin_disable.set_visible(False)


class MACSpoofSetting(AdditionalSetting):
    def __init__(self, greeter, builder):
        super().__init__("macspoof", greeter, builder)
        self.accel_key = Gdk.KEY_m

    def build_ui(self, builder):
        super().build_ui(builder)
        tailsgreeter.utils.import_builder_objects(self, builder, [
                'image_macspoof_off',
                'image_macspoof_on',
                'label_macspoof_value',
                'listboxrow_macspoof_off',
                'listboxrow_macspoof_on',
                ])

    def row_activated(self, row):
        macspoof = None
        if row == self.listboxrow_macspoof_on:
            macspoof = True
            self.image_macspoof_on.set_visible(True)
            self.image_macspoof_off.set_visible(False)
        elif row == self.listboxrow_macspoof_off:
            macspoof = False
            self.image_macspoof_off.set_visible(True)
            self.image_macspoof_on.set_visible(False)
        self.greeter.physical_security.macspoof = macspoof
        self.label_macspoof_value.set_label(
                tailsgreeter.utils.get_on_off_string(macspoof, default=True))


class NetworkSetting(AdditionalSetting):
    def __init__(self, greeter, builder):
        super().__init__("network", greeter, builder)
        self.accel_key = Gdk.KEY_n

    def build_ui(self, builder):
        super().build_ui(builder)
        tailsgreeter.utils.import_builder_objects(self, builder, [
                'infobar_network',
                'image_network_clear',
                'image_network_specific',
                'image_network_off',
                'label_network_value',
                'listboxrow_network_clear',
                'listboxrow_network_specific',
                'listboxrow_network_off',
                ])

    def build_popover(self):
        super().build_popover()
        self.show_bridge_info_if_needed()

    def row_activated(self, row):
        netconf = None
        if row == self.listboxrow_network_clear:
            netconf = self.greeter.physical_security.NETCONF_DIRECT
            self.image_network_clear.set_visible(True)
            self.image_network_specific.set_visible(False)
            self.image_network_off.set_visible(False)
            self.label_network_value.set_label(_("Direct (default)"))
        elif row == self.listboxrow_network_specific:
            netconf = self.greeter.physical_security.NETCONF_OBSTACLE
            self.image_network_specific.set_visible(True)
            self.image_network_clear.set_visible(False)
            self.image_network_off.set_visible(False)
            self.label_network_value.set_label(_("Bridge & Proxy"))
        elif row == self.listboxrow_network_off:
            netconf = self.greeter.physical_security.NETCONF_DISABLED
            self.image_network_off.set_visible(True)
            self.image_network_specific.set_visible(False)
            self.image_network_clear.set_visible(False)
            self.label_network_value.set_label(_("Offline"))
        if netconf:
            self.greeter.physical_security.netconf = netconf

    def show_bridge_info_if_needed(self):
        if (self.greeter.physical_security.netconf ==
                self.greeter.physical_security.NETCONF_OBSTACLE):
            self.infobar_network.set_visible(True)
        else:
            self.infobar_network.set_visible(False)


class CamouflageSetting(AdditionalSetting):
    def __init__(self, greeter, builder):
        super().__init__("camouflage", greeter, builder)

    def build_ui(self, builder):
        super().build_ui(builder)
        tailsgreeter.utils.import_builder_objects(self, builder, [
                'label_camouflage_value'])

    def switch_active(self, switch):
        state = switch.get_active()
        if state:
            self.greeter.camouflage.os = 'win8'
        else:
            self.greeter.camouflage.os = None
        self.label_camouflage_value.set_label(
                tailsgreeter.utils.get_on_off_string(state, default=None))


class PersistentStorage(object):
    def __init__(self, greeter, builder):
        self.greeter = greeter
        self.build_ui(builder)

    def build_ui(self, builder):
        tailsgreeter.utils.import_builder_objects(self, builder, [
                'box_storage',
                'box_storage_unlock',
                'box_storage_unlocked',
                'button_storage_configure',
                'button_storage_unlock',
                'checkbutton_storage_show_passphrase',
                'entry_storage_passphrase',
                'image_storage_state',
                'infobar_persistence',
                'label_infobar_persistence',
                'spinner_storage_unlock',
                ])

        if self.greeter.persistence.has_persistence():
            self.button_storage_configure.set_visible(False)
            self.checkbutton_storage_show_passphrase.set_visible(True)
            self.box_storage_unlock.set_visible(True)
            self.image_storage_state.set_visible(True)
            self.entry_storage_passphrase.set_visible(True)
            self.spinner_storage_unlock.set_visible(False)
        else:
            # XXX-future: We have a nice button to configure the persistence
            # but nothing is implemented to do so currently. So let's
            # hide the whole thing for now.
            self.box_storage.set_visible(False)

    def configure(self):
        # XXX-future: this should launch the configuration of the persistence.
        logging.warn("User would be able to set up an encrypted storage.")
        raise NotImplementedError

    def lock(self):
        if self.greeter.persistence.lock():
            self.button_storage_lock.set_visible(False)
            self.checkbutton_storage_show_passphrase.set_visible(True)
            self.box_storage_unlock.set_visible(True)
            self.image_storage_state.set_visible(True)
            self.image_storage_state.set_from_icon_name(
                    'tails-locked', Gtk.IconSize.BUTTON)
            self.entry_storage_passphrase.set_visible(True)
            self.entry_storage_passphrase.set_sensitive(True)
            self.button_storage_unlock.set_visible(True)
            self.button_storage_unlock.set_sensitive(True)
            self.button_storage_unlock.set_label(_("Unlock"))
        else:
            self.label_infobar_persistence.set_label(
                    _("Failed to relock persistent storage."))
            self.infobar_persistence.set_visible(True)

    def passphrase_changed(self, editable):
        # Remove warning icon
        editable.set_icon_from_icon_name(
                Gtk.EntryIconPosition.SECONDARY,
                None)

    def unlock(self, unlocked_cb=None, failed_cb=None):
        if not unlocked_cb:
            unlocked_cb = self.cb_unlocked
        if not failed_cb:
            failed_cb = self.cb_unlock_failed

        self.checkbutton_storage_show_passphrase.set_visible(False)
        self.entry_storage_passphrase.set_sensitive(False)
        self.button_storage_unlock.set_sensitive(False)
        self.button_storage_unlock.set_label(_("Unlocking…"))
        self.image_storage_state.set_visible(False)
        self.spinner_storage_unlock.set_visible(True)

        passphrase = self.entry_storage_passphrase.get_text()

        # Let's execute the unlocking in a thread
        def do_unlock_storage(unlock_method, passphrase, unlocked_cb,
                              failed_cb):
            if unlock_method(passphrase):
                GLib.idle_add(unlocked_cb)
            else:
                GLib.idle_add(failed_cb)

        unlocking_thread = threading.Thread(
                target=do_unlock_storage,
                args=(self.greeter.persistence.unlock,
                      passphrase,
                      unlocked_cb,
                      failed_cb)

                )
        unlocking_thread.start()

    def cb_unlock_failed(self):
        logging.debug("Storage unlock failed")
        self.checkbutton_storage_show_passphrase.set_visible(True)
        self.entry_storage_passphrase.set_sensitive(True)
        self.button_storage_unlock.set_sensitive(True)
        self.button_storage_unlock.set_label(_("Unlock"))
        self.image_storage_state.set_visible(True)
        self.spinner_storage_unlock.set_visible(False)
        self.label_infobar_persistence.set_label(
                _("Cannot unlock encrypted storage with this passphrase."))
        self.infobar_persistence.set_visible(True)
        self.entry_storage_passphrase.select_region(0, -1)
        self.entry_storage_passphrase.set_icon_from_icon_name(
                Gtk.EntryIconPosition.SECONDARY,
                'dialog-warning-symbolic')
        self.entry_storage_passphrase.grab_focus()

    def cb_unlocked(self):
        logging.debug("Storage unlocked")
        self.spinner_storage_unlock.set_visible(False)
        self.entry_storage_passphrase.set_visible(False)
        self.button_storage_unlock.set_visible(False)
        self.infobar_persistence.set_visible(False)
        self.image_storage_state.set_from_icon_name('tails-unlocked',
                                                    Gtk.IconSize.BUTTON)
        self.image_storage_state.set_visible(True)
        self.box_storage_unlocked.set_visible(True)


class GreeterSettingsCollection(object):
    def __init__(self, greeter, builder):
        # Region settings
        self.text = TextSetting(greeter, builder)
        self.keyboard = KeyboardSetting(greeter, builder)
        self.formats = FormatsSetting(greeter, builder)
        self.timezone = TimezoneSetting(greeter, builder)

        # Additional settings views
        self.admin = AdminSetting(greeter, builder)
        self.macspoof = MACSpoofSetting(greeter, builder)
        self.network = NetworkSetting(greeter, builder)
        self.camouflage = CamouflageSetting(greeter, builder)

    def __getitem__(self, key):
        return self.__getattribute__(key)

    def __iter__(self):
        return iter([getattr(self, k) for k in self.__dict__.keys()])


class DialogAddSetting(Gtk.Dialog):
    def __init__(self, builder, settings):
        super().__init__(use_header_bar=True)
        self.build_ui(builder)
        self.settings = settings

    def build_ui(self, builder):
        tailsgreeter.utils.import_builder_objects(self, builder, [
                'box_admin_popover',
                'box_camouflage_popover',
                'box_macspoof_popover',
                'box_network_popover',
                'entry_admin_password',
                'listbox_add_setting',
                'listboxrow_admin',
                'listboxrow_camouflage',
                'listboxrow_macspoof',
                'listboxrow_network',
                ])

        self.set_transient_for(self)
        self.set_title(_("Additional Settings"))
        self.set_default_size(-1, ADD_SETTING_DIALOG_PREFERRED_WIDTH)

        sizegroup = Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL)

        accelgroup = Gtk.AccelGroup.new()
        self.add_accel_group(accelgroup)

        self.button_cancel = self.add_button(_("Cancel"),
                                             Gtk.ResponseType.CANCEL)
        accelgroup.connect(Gdk.KEY_Escape, 0, 0,
                           self.cb_accelgroup_cancel_activated)
        sizegroup.add_widget(self.button_cancel)

        self.button_add = self.add_button(_("Add"), Gtk.ResponseType.YES)
        Gtk.StyleContext.add_class(self.button_add.get_style_context(),
                                   'suggested-action')
        sizegroup.add_widget(self.button_add)
        accelgroup.connect(Gdk.KEY_Return, 0, 0,
                           self.cb_accelgroup_add_activated)
        self.button_add.set_visible(False)

        self.button_back = Gtk.Button.new_with_label(_("Back"))
        self.button_back.set_visible(False)
        self.button_back.connect('clicked', self.cb_button_back_clicked, None)
        sizegroup.add_widget(self.button_back)
        accelgroup.connect(Gdk.KEY_Back, 0, 0,
                           self.cb_accelgroup_back_activated)
        # These key bindings are copied from Firefox, and are the same with
        # right-to-left languages.
        accelgroup.connect(Gdk.KEY_Left, Gdk.ModifierType.MOD1_MASK, 0,
                           self.cb_accelgroup_back_activated)
        accelgroup.connect(Gdk.KEY_KP_Left, Gdk.ModifierType.MOD1_MASK, 0,
                           self.cb_accelgroup_back_activated)
        self.get_header_bar().pack_end(self.button_back)

        self.stack = Gtk.Stack()
        self.stack.add_named(self.listbox_add_setting, "setting-type")
        self.listbox_add_setting.set_valign(Gtk.Align.FILL)
        self.listbox_add_setting.set_vexpand(True)
        self.stack.set_visible(True)
        # XXX: is SLIDE_LEFT_RIGHT automatically inversed in RTL mode?
        self.stack.set_transition_type(
                Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.get_content_area().add(self.stack)

    def go_back(self):
        self.stack.set_visible_child_name('setting-type')
        self.button_back.set_visible(False)
        self.button_add.set_visible(False)
        self.stack.remove(self.stack.get_child_by_name('setting-details'))

    def listbox_focus(self):
        # Workaround autoselection of 1st item on focus
        self.listbox_add_setting.unselect_all()

    def listbox_row_activated(self, row):
        if not row:  # this happens when the row gets unselected
            return False
        setting_id = tailsgreeter.utils.setting_id_from_row(row)
        self.stack.add_named(self.settings[setting_id].box, 'setting-details')
        self.stack.set_visible_child_name('setting-details')
        # XXX: this is an ugly workaround for a buggy default focus
        if setting_id == "admin":
            self.entry_admin_password.grab_focus()
        self.button_back.set_visible(True)
        self.button_add.set_visible(True)

    def run(self, setting_id=None):
        if setting_id:
            row = self.settings[setting_id].listboxrow
            row.emit("activate")
        else:
            self.stack.set_visible_child_name('setting-type')
            self.button_back.set_visible(False)
            self.button_add.set_visible(False)
        return super().run()

    def cb_accelgroup_add_activated(self, accel_group, accelerable, keyval,
                                    modifier, user_data=None):
        if self.button_add.get_visible() and self.button_add.get_sensitive():
            self.response(Gtk.ResponseType.YES)
        return False

    def cb_accelgroup_back_activated(self, accel_group, accelerable, keyval,
                                     modifier, user_data=None):
        self.go_back()
        return False

    def cb_accelgroup_cancel_activated(self, accel_group, accelerable, keyval,
                                       modifier, user_data=None):
        self.response(Gtk.ResponseType.CANCEL)
        return True  # disable the default callbacks that destroys the dialog

    def cb_button_back_clicked(self, widget, user_data=None):
        self.go_back()
        return False


class GreeterMainWindow(Gtk.Window, TranslatableWindow):

    def __init__(self, greeter):
        Gtk.Window.__init__(self, title=_(tailsgreeter.APPLICATION_TITLE))
        TranslatableWindow.__init__(self, self)
        self.greeter = greeter

        self._build_ui()
        self.store_translations(self)

        self.connect('delete-event', self.cb_window_delete_event, None)
        self.set_position(Gtk.WindowPosition.CENTER)

    # Utility methods

    def __align_checkbuttons(self):
        """Put the text before the checkbox rather than the opposite (assuming
        LTR), because it's what designers want."""
        for checkbutton in [self.checkbutton_language_save,
                            self.checkbutton_storage_show_passphrase,
                            self.checkbutton_settings_save]:
            checkbutton.set_direction(not Gtk.Widget.get_default_direction())

    def _build_accelerators(self):
        accelgroup = Gtk.AccelGroup.new()
        self.add_accel_group(accelgroup)
        for accel_key in [s.accel_key for s in self.settings if s.accel_key]:
            accelgroup.connect(
                accel_key,
                Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK,
                Gtk.AccelFlags.VISIBLE,
                self.cb_accelgroup_setting_activated)

    def _build_headerbar(self):
        headerbar = Gtk.HeaderBar()
        headerbar_sizegroup = Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL)

        self.button_shutdown = Gtk.Button.new_with_label(_("Shutdown"))
        self.button_shutdown.connect('clicked', self.cb_button_shutdown_clicked)
        headerbar_sizegroup.add_widget(self.button_shutdown)
        headerbar.pack_start(self.button_shutdown)

        self.button_start = Gtk.Button.new_with_mnemonic(_("_Start Tails"))
        Gtk.StyleContext.add_class(self.button_start.get_style_context(),
                                   'suggested-action')
        self.button_start.connect('clicked', self.cb_button_start_clicked)
        headerbar_sizegroup.add_widget(self.button_start)
        headerbar.pack_end(self.button_start)

        # XXX-future: the button Take a tour is for phase 2
        # button_tour = Gtk.Button.new_with_label(_("Take a Tour"))
        # button_tour.connect('clicked', self.cb_button_tour_clicked)
        # headerbar_sizegroup.add_widget(button_tour)
        # headerbar.pack_end(button_tour)

        headerbar.show_all()

        return headerbar

    def _build_ui(self):
        # Load custom CSS
        css_provider = Gtk.CssProvider.new()
        css_provider.load_from_path(tailsgreeter.config.data_path + CSS_FILE)
        Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        # Load UI interface definition
        builder = Gtk.Builder()
        builder.set_translation_domain(TRANSLATION_DOMAIN)
        builder.add_from_file(tailsgreeter.config.data_path + UI_FILE)
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

        tailsgreeter.utils.import_builder_objects(self, builder, [
                'box_admin_popover',
                'box_camouflage_popover',
                'box_language',
                'box_language_header',
                'box_macspoof_popover',
                'box_main',
                'box_network_popover',
                'box_settings',
                'box_settings_header',
                'box_settings_values',
                'box_storage',
                'box_storage_unlock',
                'box_storage_unlocked',
                'button_storage_configure',
                'checkbutton_language_save',
                'checkbutton_settings_save',
                'checkbutton_storage_show_passphrase',
                'entry_admin_verify',
                'entry_storage_passphrase',
                'frame_language',
                'label_settings_default',
                'listbox_add_setting',
                'listbox_settings',
                'listboxrow_formats',
                'listboxrow_keyboard',
                'listboxrow_admin',
                'listboxrow_camouflage',
                'listboxrow_macspoof',
                'listboxrow_network',
                'listboxrow_text',
                'listboxrow_tz',
                'switch_camouflage',
                'toolbutton_settings_add',
                ])

        # Set preferred width
        self.set_default_size(min(Gdk.Screen.get_default().get_width(),
                                  MAIN_WINDOW_PREFERRED_WIDTH),
                              min(Gdk.Screen.get_default().get_height(),
                                  MAIN_WINDOW_PREFERRED_HEIGHT))

        # Add our icon dir to icon theme
        icon_theme = Gtk.IconTheme.get_default()
        icon_theme.prepend_search_path(
            tailsgreeter.config.data_path + ICON_DIR)

        # Add placeholder to settings ListBox
        self.listbox_settings.set_placeholder(self.label_settings_default)

        # Settings view
        self.settings = GreeterSettingsCollection(self.greeter, builder)

        # Persistent storage
        self.persistent_storage = PersistentStorage(self.greeter, builder)

        # Add children to ApplicationWindow
        self.add(self.box_main)
        self.set_titlebar(self._build_headerbar())

        # Set keyboard focus chain
        self.__set_focus_chain()

        # Setup keyboard accelerators
        self._build_accelerators()

        # Adapt CheckButtons direction to the mockups
        self.__align_checkbuttons()

        # Add settings dialog
        self.dialog_add_setting = DialogAddSetting(builder, self.settings)
        self.dialog_add_setting.set_transient_for(self)
        self.store_translations(self.dialog_add_setting)

        # Settings popovers
        self.switch_camouflage.connect('notify::active',
                                       self.cb_switch_camouflage_active)

    def __set_focus_chain(self):
        self.box_language.set_focus_chain([
                self.frame_language,
                self.box_language_header])
        self.box_storage.set_focus_chain([
                self.box_storage_unlock,
                self.box_storage_unlocked,
                self.button_storage_configure,
                self.checkbutton_storage_show_passphrase])
        self.box_settings.set_focus_chain([
                self.box_settings_values,
                self.box_settings_header])

    # TranslatableWindow implementation
    def translate_to(self, lang):
        TranslatableWindow.translate_to(self, lang)
        self.__align_checkbuttons()

    # Actions

    def check_and_login(self):
        if (self.greeter.persistence.has_persistence() and
                self.entry_storage_passphrase.get_text() and
                not self.greeter.persistence.is_unlocked):
            logging.debug("Unlocking persistent storage before login")
            self.persistent_storage.unlock(unlocked_cb=self.finish_login)
        else:
            self.finish_login()

    def finish_login(self):
        logging.info("Starting the session")
        self.greeter.login()
        return False

    def setting_add(self, setting_id=None):
        response = self.dialog_add_setting.run(setting_id)
        if response == Gtk.ResponseType.YES:
            row = self.listbox_add_setting.get_selected_row()
            setting_id = tailsgreeter.utils.setting_id_from_row(row)
            box = self.__getattribute__("box_{}_popover".format(setting_id))

            self.listbox_add_setting.remove(row)
            self.listbox_settings.add(row)
            self.dialog_add_setting.set_visible(False)
            self.dialog_add_setting.stack.remove(box)
            self.settings[setting_id].build_popover()

            self.listbox_settings.unselect_all()
            if True not in [c.get_visible() for c in
                            self.listbox_add_setting.get_children()]:
                self.toolbutton_settings_add.set_sensitive(False)
            self.dialog_add_setting.set_visible(False)
        else:
            old_details = self.dialog_add_setting.stack.get_child_by_name(
                    'setting-details')
            if old_details:
                self.dialog_add_setting.stack.remove(old_details)
            self.dialog_add_setting.set_visible(False)

    def setting_edit(self, setting_id):
        if self.settings[setting_id].has_popover():
            self.settings[setting_id].listboxrow.emit("activate")
        else:
            self.setting_add(setting_id)

    def setting_admin_check(self):
        match = self.settings.admin.check()
        self.dialog_add_setting.button_add.set_sensitive(match)

    def setting_admin_apply(self):
        if (self.settings.admin.apply() and
                not self.settings.admin.close_popover_if_any()):
            # There is no popover, because we are in the add setting dialog
            self.dialog_add_setting.response(Gtk.ResponseType.YES)

    def setting_admin_disable(self):
        self.settings.admin.disable()
        self.settings.admin.close_popover_if_any()

    def setting_network_close(self, only_if_popover=False):
        if self.settings.network.close_popover_if_any():
            # we are in the popover
            self.settings.network.show_bridge_info_if_needed()
        elif not only_if_popover:
            # We are in the "Add Additional Setting" dialog
            self.dialog_add_setting.response(Gtk.ResponseType.YES)

    def show(self):
        super().show()
        self.button_start.grab_focus()
        self.get_root_window().set_cursor(Gdk.Cursor.new(Gdk.CursorType.ARROW))

    # Callbacks

    # XXX-refactor: some of these callbacks could be totally moved out of this
    # class

    def cb_accelgroup_setting_activated(self, accel_group, accelerable,
                                        keyval, modifier):
        for setting in self.settings:
            if setting.accel_key == keyval:
                self.setting_edit(setting.setting_id)
        return False

    def cb_button_admin_disable_clicked(self, widget, user_data=None):
        self.setting_admin_disable()

    def cb_linkbutton_help_activate(self, linkbutton, user_data=None):
        linkbutton.set_sensitive(False)
        # Display progress cursor and update the UI
        self.get_window().set_cursor(Gdk.Cursor.new(Gdk.CursorType.WATCH))
        while Gtk.events_pending():
            Gtk.main_iteration()
        # Note that we add the "file://" part here, not in the URI.
        # We're forced to add this
        # callback *in addition* to the standard one (Gtk.show_uri),
        # which will do nothing for uri:s without a protocol
        # part. This is critical since we otherwise would open the
        # default browser (iceweasel) in T-G. If pygtk had a mechanism
        # like gtk's g_signal_handler_find() this could be dealt with
        # in a less messy way by just removing the default handler.
        page = linkbutton.get_uri()
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
        self.check_and_login()
        return False

    def cb_button_storage_configure_clicked(self, user_data=None):
        self.persistent_storage.configure()
        return False

    def cb_button_tour_clicked(self, user_data=None):
        # XXX-future: the button Take a tour is for phase 2
        raise NotImplementedError
        return False

    def cb_button_storage_lock_clicked(self, widget, user_data=None):
        self.persistent_storage.lock()
        return False

    def cb_button_storage_unlock_clicked(self, widget, user_data=None):
        self.persistent_storage.unlock()
        return False

    def cb_checkbutton_storage_show_passphrase_toggled(self, widget,
                                                       user_data=None):
        self.entry_storage_passphrase.set_visibility(widget.get_active())

    def cb_entry_admin_changed(self, editable, user_data=None):
        self.setting_admin_check()
        return False

    def cb_entry_admin_focus_out_event(self, widget, event, user_data=None):
        self.setting_admin_apply()
        return False

    def cb_entry_admin_password_activate(self, widget, user_data=None):
        self.entry_admin_verify.grab_focus()
        return False

    def cb_entry_admin_verify_activate(self, widget, user_data=None):
        self.setting_admin_apply()
        return False

    def cb_entry_storage_passphrase_activated(self, entry, user_data=None):
        self.persistent_storage.unlock()
        return False

    def cb_entry_storage_passphrase_changed(self, editable, user_data=None):
        self.persistent_storage.passphrase_changed(editable)
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

    def cb_listbox_add_setting_row_activated(self, listbox, row,
                                             user_data=None):
        self.dialog_add_setting.listbox_row_activated(row)
        return False

    # XXX-refactor: an object could wrap the whole RegionSettings box
    def cb_listbox_language_row_activated(self, listbox, row, user_data=None):
        setting_id = tailsgreeter.utils.setting_id_from_row(row)
        tailsgreeter.utils.popover_toggle(self.settings[setting_id].popover)
        return False

    def cb_listbox_network_button_press(self, widget, event, user_data=None):
        if event.type == Gdk.EventType._2BUTTON_PRESS:
            self.setting_network_close()
        return False

    def cb_listbox_macspoof_row_activated(self, listbox, row, user_data=None):
        self.settings.macspoof.row_activated(row)
        self.settings.macspoof.close_popover_if_any()

    def cb_listbox_network_row_activated(self, listbox, row, user_data=None):
        self.settings.network.row_activated(row)
        self.setting_network_close(only_if_popover=True)
        return False

    def cb_listbox_settings_row_activated(self, listbox, row, user_data=None):
        setting_id = tailsgreeter.utils.setting_id_from_row(row)
        tailsgreeter.utils.popover_toggle(self.settings[setting_id].popover)
        return False

    def cb_switch_camouflage_active(self, switch, pspec, user_data=None):
        self.settings.camouflage.switch_active(switch)
        self.settings.camouflage.close_popover_if_any()

    def cb_toolbutton_settings_add_clicked(self, user_data=None):
        self.setting_add()
        return False

    def cb_toolbutton_settings_mnemonic_activate(self, widget, group_cycling):
        self.setting_add()
        return False

    def cb_window_delete_event(self, widget, event, user_data=None):
        # Don't close the toplevel window on user request (e.g. pressing
        # Alt+F4)
        return True


class GreeterHelpWindow(Gtk.Window, TranslatableWindow):
    """Displays a modal HTML help window"""

    def __init__(self, uri):
        Gtk.Window.__init__(self, title=_(tailsgreeter.APPLICATION_TITLE))
        TranslatableWindow.__init__(self, self)

        self._build_ui()
        self.store_translations(self)

        self.load_uri(uri)
        # Replace the busy cursor set by the tails-greeter startup script with
        # the default cursor.
        self.get_window().set_cursor(None)

    def _build_ui(self):
        self.set_position(Gtk.WindowPosition.CENTER)

        # Create HeaderBar
        headerbar = Gtk.HeaderBar()
        headerbar.set_show_close_button(True)
        headerbar.show_all()

        # Create webview with custom stylesheet
        css = WebKit2.UserStyleSheet(
                ".sidebar, .banner { display: none; }",
                WebKit2.UserContentInjectedFrames.ALL_FRAMES,
                WebKit2.UserStyleLevel.USER,
                None,
                None)
        content_manager = WebKit2.UserContentManager()
        content_manager.add_style_sheet(css)
        self.webview = WebKit2.WebView.new_with_user_content_manager(
                content_manager)
        self.webview.connect("resource-load-started",
                             self.cb_load_started)
        self.webview.show()

        scrolledwindow = Gtk.ScrolledWindow()
        scrolledwindow.add(self.webview)
        scrolledwindow.show()

        # Add children to ApplicationWindow
        self.add(scrolledwindow)
        self.set_titlebar(headerbar)

    def load_uri(self, uri):
        self.webview.load_uri(uri)
        self.resize(
                min(HELP_WINDOW_PREFERRED_WIDTH,
                    self.get_screen().get_width()),
                self.get_screen().get_height())
        self.present()

    def cb_load_started(self, web_view, ressource, request):
        if not request.get_uri().startswith("file://"):
            webbrowser.open_new(request.get_uri())
            request.set_uri(web_view.get_uri())


class GreeterBackgroundWindow(Gtk.ApplicationWindow):

    def __init__(self, app):
        Gtk.Window.__init__(self, title=_(tailsgreeter.APPLICATION_TITLE),
                            application=app)
        self.override_background_color(
                Gtk.StateFlags.NORMAL, Gdk.RGBA(0, 0, 0, 1))
