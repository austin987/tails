import logging
import gi
import threading
from typing import TYPE_CHECKING

from tailsgreeter.ui import _

gi.require_version('GLib', '2.0')
gi.require_version('Gtk', '3.0')
from gi.repository import GLib, Gtk

if TYPE_CHECKING:
    from tailsgreeter.settings.persistence import PersistenceSettings


class PersistentStorage(object):
    def __init__(self, persistence_setting: "PersistenceSettings", builder):
        self.persistence_setting = persistence_setting

        self.box_storage = builder.get_object('box_storage')
        self.box_storage_unlock = builder.get_object('box_storage_unlock')
        self.box_storage_unlocked = builder.get_object('box_storage_unlocked')
        self.button_storage_configure = builder.get_object('button_storage_configure')
        self.button_storage_lock = builder.get_object('button_storage_lock')
        self.button_storage_unlock = builder.get_object('button_storage_unlock')
        self.entry_storage_passphrase = builder.get_object('entry_storage_passphrase')
        self.image_storage_state = builder.get_object('image_storage_state')
        self.infobar_persistence = builder.get_object('infobar_persistence')
        self.label_infobar_persistence = builder.get_object('label_infobar_persistence')
        self.spinner_storage_unlock = builder.get_object('spinner_storage_unlock')

        if self.persistence_setting.has_persistence():
            self.button_storage_configure.set_visible(False)
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
        logging.warning("User would be able to set up an encrypted storage.")
        raise NotImplementedError

    def lock(self):
        if self.persistence_setting.lock():
            self.button_storage_lock.set_visible(False)
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

    @staticmethod
    def passphrase_changed(editable):
        # Remove warning icon
        editable.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY, None)

    def unlock(self, unlocked_cb=None, failed_cb=None):
        if not unlocked_cb:
            unlocked_cb = self.cb_unlocked
        if not failed_cb:
            failed_cb = self.cb_unlock_failed

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
                args=(self.persistence_setting.unlock,
                      passphrase,
                      unlocked_cb,
                      failed_cb)

                )
        unlocking_thread.start()

    def cb_unlock_failed(self):
        logging.debug("Storage unlock failed")
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
