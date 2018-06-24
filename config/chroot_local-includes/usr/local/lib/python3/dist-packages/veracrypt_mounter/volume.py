from logging import getLogger
import abc
import subprocess

# Only required for type hints
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from veracrypt_mounter.volume_manager import VolumeManager

from gi.repository import Gtk, GLib, Gio, UDisks, GObject

logger = getLogger(__name__)


class Volume(object, metaclass=abc.ABCMeta):
    def __init__(self, manager: "VolumeManager",
                 gio_volume: Gio.Volume,
                 udisks_object: UDisks.Object,
                 udisks_backing_object: UDisks.Object = None):
        self.manager = manager
        self.gio_volume = gio_volume
        self.udisks_object = udisks_object
        self.udisks_backing_object = udisks_backing_object
        self.list_box_row = None
        self.spinner_is_showing = False
        self.dialog_is_showing = False

    @property
    @abc.abstractmethod
    def label(self) -> str:
        pass

    @property
    def device_file(self) -> str:
        return self.gio_volume.get_identifier(Gio.VOLUME_IDENTIFIER_KIND_UNIX_DEVICE)

    @property
    def is_unlocked(self) -> bool:
        return bool(self.udisks_backing_object)

    @property
    def is_loop_device(self) -> bool:
        return bool(self.udisks_object.get_loop())

    def unlock(self):
        def on_is_showing_dialog_changed(mount_op: Gtk.MountOperation, param_spec: GObject.ParamSpec):
            # XXX: For some reason `mount_operation.is_showing()` always returns False here,
            #      so we use the `dialog_is_showing` variable to figure out whether the dialog
            #      is showing or not
            self.dialog_is_showing = not self.dialog_is_showing
            if not self.dialog_is_showing and not self.spinner_is_showing:
                self.show_spinner()

        def mount_cb(volume: Gio.Volume, result: Gio.AsyncResult):
            try:
                volume.mount_finish(result)
            except GLib.Error as e:
                if "Password dialog aborted" in e.message or "The authentication dialog was dismissed" in e.message:
                    # Refresh the volume list to get rid of the spinner
                    self.manager.refresh_volume_list()
                    return
                raise

        logger.debug("Unlocking volume %s", self.device_file)
        self.dialog_is_showing = False
        mount_operation = Gtk.MountOperation()
        mount_operation.connect("notify::is-showing", on_is_showing_dialog_changed)

        self.gio_volume.mount(0,                # Gio.MountMountFlags
                              mount_operation,  # Gio.MountOperation
                              None,             # Gio.Cancellable
                              mount_cb)         # callback

    def lock(self):
        self.unmount()
        self.udisks_backing_object.get_encrypted().call_lock_sync(GLib.Variant('a{sv}', {}),  # options
                                                                  None)                       # cancellable

    def unmount(self):
        while self.udisks_object.get_filesystem().props.mount_points:
            try:
                self.udisks_object.get_filesystem().call_unmount_sync(GLib.Variant('a{sv}', {}),  # options
                                                                      None)                       # cancellable
            except GLib.Error as e:
                if "org.freedesktop.UDisks2.Error.NotMounted" in e.message:
                    return
                raise

    def detach_loop_device(self):
        self.udisks_object.get_loop().call_delete_sync(GLib.Variant('a{sv}', {}),  # options
                                                       None)                       # cancellable

    def open(self):
        mount_point = self.udisks_object.get_filesystem().props.mount_points[0]
        subprocess.Popen(["xdg-open", mount_point])

    def show_spinner(self):
        if self.spinner_is_showing:
            return

        box = self.list_box_row.get_child()

        # Remove the button box
        box.remove(box.get_children()[-1])

        spinner = Gtk.Spinner()
        box.add(spinner)
        spinner.start()

        box.show_all()
        self.spinner_is_showing = True

    def on_lock_button_clicked(self, button):
        logger.debug("in on_lock_button_clicked")
        self.lock()

    def on_unlock_button_clicked(self, button):
        logger.debug("in on_unlock_button_clicked")
        self.unlock()

    def on_detach_button_clicked(self, button):
        logger.debug("in on_detach_button_clicked")
        self.detach_loop_device()

    def on_open_button_clicked(self, button):
        logger.debug("in on_open_button_clicked")
        self.open()


class Container(Volume):
    @property
    def label(self) -> str:
        if self.is_unlocked:
            return "%s – %s" % (self.gio_volume.get_name(), self.udisks_backing_object.get_loop().props.backing_file)
        else:
            return "%s – %s" % (self.gio_volume.get_name(), self.udisks_object.get_loop().props.backing_file)


class Device(Volume):
    @property
    def label(self) -> str:
        return "%s – %s" % (self.gio_volume.get_name(),
                            self.gio_volume.get_identifier(Gio.VOLUME_IDENTIFIER_KIND_UNIX_DEVICE))
