import gi

from tailsgreeter import TRANSLATION_DOMAIN
import tailsgreeter.config
import tailsgreeter.utils
from tailsgreeter.ui import _
from tailsgreeter.ui.setting import GreeterSetting
from tailsgreeter.ui.popover import Popover
from typing import TYPE_CHECKING

gi.require_version('Gdk', '3.0')
gi.require_version('Gtk', '3.0')
from gi.repository import Gdk, Gtk

if TYPE_CHECKING:
    from tailsgreeter.settings.admin import AdminSetting
    from tailsgreeter.settings.macspoof import MacSpoofSetting
    from tailsgreeter.settings.network import NetworkSetting

ADDITIONAL_SETTINGS_UI_FILE = "additional_settings.ui"


class AdditionalSetting(GreeterSetting):
    def __init__(self):
        super().__init__()
        self.dialog = None

        self.builder = Gtk.Builder()
        self.builder.set_translation_domain(TRANSLATION_DOMAIN)
        self.builder.add_from_file(tailsgreeter.config.data_path + ADDITIONAL_SETTINGS_UI_FILE)
        self.box = self.builder.get_object("box_{}_popover".format(self.id))

    def build_popover(self):
        self.popover = Popover(self.listboxrow, self.box)

    def close_window(self, response: Gtk.ResponseType):
        if self.has_popover() and self.popover.is_open():
            self.popover.close(response)
        else:
            self.dialog.response(response)

    def apply(self):
        pass

    def on_opened_in_dialog(self):
        pass


class AdminSettingUI(AdditionalSetting):
    @property
    def id(self) -> str:
        return "admin"

    @property
    def title(self) -> str:
        return _("_Administration Password")

    @property
    def icon_name(self) -> str:
        return "tails-admin"

    @property
    def value_for_display(self) -> str:
        return get_on_off_string(self.password, default=None)

    def update_check_icon(self):
        password = self.password_entry.get_text()
        password_verify = self.password_verify_entry.get_text()
        if not password_verify:
            icon = None
        elif password_verify == password:
            icon = 'emblem-ok-symbolic'
        else:
            icon = 'dialog-warning-symbolic'
        self.password_verify_entry.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY, icon)

    def on_opened_in_dialog(self):
        self.update_check_icon()
        self.dialog.button_add.set_sensitive(self.passwords_match())
        self.password_entry.grab_focus()

    def __init__(self, admin_setting: "AdminSetting"):
        self._admin_setting = admin_setting
        self.password = None
        super().__init__()
        self.accel_key = Gdk.KEY_a

        self.password_entry = self.builder.get_object('entry_admin_password')
        self.password_entry.connect('changed', self.cb_entry_admin_changed)
        self.password_entry.connect('activate', self.cb_entry_admin_activate)
        self.password_verify_entry = self.builder.get_object('entry_admin_verify')
        self.password_verify_entry.connect('changed', self.cb_entry_admin_changed)
        self.password_verify_entry.connect('activate', self.cb_entry_admin_activate)
        self.box_admin_password = self.builder.get_object('box_admin_password')
        self.box_admin_verify = self.builder.get_object('box_admin_verify')
        self.button_admin_disable = self.builder.get_object('button_admin_disable')
        self.button_admin_disable.connect('clicked', self.cb_button_admin_disable_clicked)

    def build_popover(self):
        super().build_popover()
        self.popover.opened_cb = self.cb_popover_opened

    def cb_popover_opened(self, popover, user_data=None):
        self.password_verify_entry.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY, None)
        password_already_set = bool(self.password)
        self.box_admin_password.set_visible(not password_already_set)
        self.box_admin_verify.set_visible(not password_already_set)
        self.button_admin_disable.set_visible(password_already_set)

    def passwords_match(self) -> bool:
        password = self.password_entry.get_text()
        # Don't accept an empty password
        if not password:
            return False
        return password == self.password_verify_entry.get_text()

    def apply(self):
        # This writes the password to a file from which it will be set
        # as the amnesia password when the greeter is closed.
        self._admin_setting.password = self.password

    def cb_entry_admin_changed(self, editable, user_data=None):
        self.update_check_icon()
        passwords_match = self.passwords_match()
        self.dialog.button_add.set_sensitive(passwords_match)
        if passwords_match:
            self.password = self.password_entry.get_text()
        return False

    def cb_entry_admin_activate(self, widget, user_data=None):
        if not self.passwords_match():
            self.dialog.button_add.set_sensitive(False)
            self.password_verify_entry.grab_focus()
            return False

        self.password = self.password_entry.get_text()
        self.close_window(Gtk.ResponseType.YES)
        return False

    def cb_button_admin_disable_clicked(self, widget, user_data=None):
        self.password = None
        self.password_entry.set_text("")
        self.password_verify_entry.set_text("")

        if self.has_popover() and self.popover.is_open():
            self.popover.close(Gtk.ResponseType.YES)


class MACSpoofSettingUI(AdditionalSetting):
    @property
    def id(self) -> str:
        return "macspoof"

    @property
    def title(self) -> str:
        return _("_MAC Address Spoofing")

    @property
    def icon_name(self) -> str:
        return "tails-macspoof"

    @property
    def value_for_display(self) -> str:
        return get_on_off_string(self.spoofing_enabled, default=True)

    def __init__(self, macspoof_setting: "MacSpoofSetting"):
        self._macspoof_setting = macspoof_setting
        self.spoofing_enabled = True
        super().__init__()
        self.accel_key = Gdk.KEY_m

        self.image_macspoof_on = self.builder.get_object('image_macspoof_on')
        self.image_macspoof_off = self.builder.get_object('image_macspoof_off')
        self.listbox_macspoof_controls = self.builder.get_object('listbox_macspoof_controls')
        self.listbox_macspoof_controls.connect('row-activated', self.cb_listbox_macspoof_row_activated)
        self.listbox_macspoof_controls.connect('button-press-event', self.cb_listbox_macspoof_button_press)
        self.listboxrow_macspoof_on = self.builder.get_object('listboxrow_macspoof_on')
        self.listboxrow_macspoof_off = self.builder.get_object('listboxrow_macspoof_off')

    def apply(self):
        self._macspoof_setting.value = self.spoofing_enabled

    def cb_listbox_macspoof_row_activated(self, listbox, row, user_data=None):
        self.spoofing_enabled = row == self.listboxrow_macspoof_on
        self.image_macspoof_on.set_visible(self.spoofing_enabled)
        self.image_macspoof_off.set_visible(not self.spoofing_enabled)

        if self.has_popover() and self.popover.is_open():
            self.popover.close(Gtk.ResponseType.YES)
        return False

    def cb_listbox_macspoof_button_press(self, widget, event, user_data=None):
        # On double-click: Close the window and apply chosen setting
        if event.type == Gdk.EventType._2BUTTON_PRESS:
            self.close_window(Gtk.ResponseType.YES)
        return False


class NetworkSettingUI(AdditionalSetting):
    @property
    def id(self) -> str:
        return "network"

    @property
    def title(self) -> str:
        return _("_Network Connection")

    @property
    def icon_name(self) -> str:
        return "tails-network"

    @property
    def value_for_display(self) -> str:
        if self.value == self._network_setting.NETCONF_DIRECT:
            return _("Direct (default)")
        if self.value == self._network_setting.NETCONF_OBSTACLE:
            return _("Bridge & Proxy")
        if self.value == self._network_setting.NETCONF_DISABLED:
            return _("Offline")

    def __init__(self, network_setting: "NetworkSetting"):
        self._network_setting = network_setting
        self.value = self._network_setting.NETCONF_DIRECT
        super().__init__()
        self.accel_key = Gdk.KEY_n
        self.icon_network_clear_chosen = self.builder.get_object('image_network_clear')
        self.icon_network_specific_chosen = self.builder.get_object('image_network_specific')
        self.icon_network_off_chosen = self.builder.get_object('image_network_off')
        self.listbox_network_controls = self.builder.get_object('listbox_network_controls')
        self.listbox_network_controls.connect('button-press-event', self.cb_listbox_network_button_press)
        self.listbox_network_controls.connect('row-activated', self.cb_listbox_network_row_activated)
        self.listboxrow_network_clear = self.builder.get_object('listboxrow_network_clear')
        self.listboxrow_network_specific = self.builder.get_object('listboxrow_network_specific')
        self.listboxrow_network_off = self.builder.get_object('listboxrow_network_off')

    def apply(self):
        self._network_setting.value = self.value
        is_bridge = self.value == self._network_setting.NETCONF_OBSTACLE
        self.main_window.set_bridge_infobar_visibility(is_bridge)

    def cb_listbox_network_button_press(self, widget, event, user_data=None):
        # On double-click: Close the window and apply chosen setting
        if event.type == Gdk.EventType._2BUTTON_PRESS:
            self.close_window(Gtk.ResponseType.YES)
        return False

    def cb_listbox_network_row_activated(self, listbox, row, user_data=None):
        self.icon_network_clear_chosen.set_visible(False)
        self.icon_network_specific_chosen.set_visible(False)
        self.icon_network_off_chosen.set_visible(False)

        if row == self.listboxrow_network_clear:
            self.value = self._network_setting.NETCONF_DIRECT
            self.icon_network_clear_chosen.set_visible(True)
        elif row == self.listboxrow_network_specific:
            self.value = self._network_setting.NETCONF_OBSTACLE
            self.icon_network_specific_chosen.set_visible(True)
        elif row == self.listboxrow_network_off:
            self.value = self._network_setting.NETCONF_DISABLED
            self.icon_network_off_chosen.set_visible(True)

        if self.has_popover() and self.popover.is_open():
            self.popover.close(Gtk.ResponseType.YES)
        return False


def get_on_off_string(value, default=None) -> str:
    """Return "On", "Off", "On (default)", or "Off (default)"""
    if value and default:
        return _("On (default)")
    if value and not default:
        return _("On")
    if not value and default:
        return _("Off")
    if not value and not default:
        return _("Off (default)")
