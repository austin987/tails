from logging import getLogger
from typing import List
import abc
import itertools

from gi.repository import Gtk, Gio, UDisks, GUdev

from veracrypt_mounter.volume import Volume, Container, Device
from veracrypt_mounter.config import APP_NAME, VOLUME_UI_FILE

logger = getLogger(__name__)


class UdisksObjectNotFoundError(Exception):
    pass


class VolumeManager(object, metaclass=abc.ABCMeta):

    placeholder_label = str()

    def __init__(self, list_box: Gtk.ListBox, udisks_client: UDisks.Client):
        self.list_box = list_box
        self.udisks_client = udisks_client
        self.udisks_object_manager = udisks_client.get_object_manager()
        self.gio_volume_monitor = Gio.VolumeMonitor.get()
        self.udev_client = GUdev.Client()
        self.volumes = list()

    @abc.abstractmethod
    def get_tcrypt_volumes(self) -> List[Gio.Volume]:
        pass

    def refresh_volume_list(self):
        self.clear_volume_list()

        self.volumes = self.get_tcrypt_volumes()
        for volume in self.volumes:
            self.add_device_row(volume)

        if not self.volumes:
            self.add_placeholder()

        self.list_box.show_all()

    def clear_volume_list(self):
        for child in self.list_box.get_children():
            self.list_box.remove(child)

    def get_udisks_object_for_gio_volume(self, gio_volume: Gio.Volume) -> UDisks.Object:
        device_file = gio_volume.get_identifier(Gio.VOLUME_IDENTIFIER_KIND_UNIX_DEVICE)
        udev_volume = self.udev_client.query_by_device_file(device_file)
        if not udev_volume:
            raise UdisksObjectNotFoundError("Couldn't get udev volume for %s" % device_file)

        device_number = udev_volume.get_device_number()
        udisks_block = self.udisks_client.get_block_for_dev(device_number)
        if not udisks_block:
            raise UdisksObjectNotFoundError("Couldn't get UDisksBlock for volume %s" % device_file)

        object_path = udisks_block.get_object_path()
        return self.udisks_client.get_object(object_path)

    @staticmethod
    def udisks_object_is_tcrypt(udisks_object):
        return udisks_object.get_encrypted() and \
               udisks_object.get_block().props.id_type in ("crypto_TCRYPT", "crypto_unknown")

    @staticmethod
    def udisks_object_is_unlocked(udisks_object):
        return udisks_object.get_block().props.crypto_backing_device != "/"

    def add_device_row(self, volume: Volume):
        logger.debug("adding device row for %s", volume.device_file)

        builder = Gtk.Builder()
        builder.set_translation_domain(APP_NAME)
        builder.add_from_file(VOLUME_UI_FILE)
        builder.connect_signals(volume)

        volume_row = builder.get_object("volume_row")
        self.list_box.add(volume_row)

        label = builder.get_object("volume_label")
        label.set_label(volume.label)

        button_box = builder.get_object("volume_button_box")

        if volume.is_unlocked:
            button_box.add(builder.get_object("open_button"))
            button_box.add(builder.get_object("lock_button"))
        else:
            button_box.add(builder.get_object("unlock_button"))
            if volume.is_loop_device:
                button_box.add(builder.get_object("detach_button"))

        volume.list_box_row = volume_row

    def add_placeholder(self):
        row = Gtk.ListBoxRow(activatable=False)
        label = Gtk.Label(self.placeholder_label)
        row.add(label)
        self.list_box.add(row)


class ContainerManager(VolumeManager):
    """Manages attached file containers"""

    placeholder_label = "No file containers added"

    def get_tcrypt_volumes(self):
        return self.get_tcrypt_file_containers()

    def get_tcrypt_file_containers(self):
        """Returns attached TCRYPT encrypted file containers"""
        logger.debug("in get_tcrypt_file_containers")

        tcrypt_containers = list()
        volumes = self.gio_volume_monitor.get_volumes()
        file_container_volumes = [v for v in volumes if self.gio_volume_is_file_container(v)]

        for volume in file_container_volumes:
            logger.debug("volume: %s", volume.get_identifier(Gio.VOLUME_IDENTIFIER_KIND_UNIX_DEVICE))
            try:
                udisks_object = self.get_udisks_object_for_gio_volume(volume)
            except UdisksObjectNotFoundError as e:
                logger.exception(e)
                continue

            if self.udisks_object_is_unlocked(udisks_object):
                backing_object_path = udisks_object.get_block().props.crypto_backing_device
                backing_udisks_object = self.udisks_client.get_object(backing_object_path)
                if self.udisks_object_is_tcrypt(backing_udisks_object):
                    tcrypt_containers.append(Container(self, volume, udisks_object, backing_udisks_object))

            if self.udisks_object_is_tcrypt(udisks_object):
                tcrypt_containers.append(Container(self, volume, udisks_object))

        return tcrypt_containers

    @staticmethod
    def gio_volume_is_file_container(volume: Gio.Volume):
        device_path = volume.get_identifier(Gio.VOLUME_IDENTIFIER_KIND_UNIX_DEVICE)
        return device_path and ("/dev/loop" in device_path or "/dev/dm" in device_path)


class DeviceManager(VolumeManager):
    """Manages physically connected drives and partitions"""

    placeholder_label = "No VeraCrypt devices detected"

    def get_tcrypt_volumes(self):
        return self.get_tcrypt_devices()

    def get_tcrypt_devices(self):
        """Returns physically connected TCRYPT encrypted drives and partitions"""
        logger.debug("in get_tcrypt_devices")

        tcrypt_devices = list()
        drives = self.gio_volume_monitor.get_connected_drives()
        volumes = itertools.chain.from_iterable(d.get_volumes() for d in drives)

        for volume in volumes:
            logger.debug("volume: %s", volume.get_identifier(Gio.VOLUME_IDENTIFIER_KIND_UNIX_DEVICE))
            try:
                udisks_object = self.get_udisks_object_for_gio_volume(volume)
            except UdisksObjectNotFoundError as e:
                logger.exception(e)
                continue

            if self.udisks_object_is_unlocked(udisks_object):
                backing_object_path = udisks_object.get_block().props.crypto_backing_device
                backing_udisks_object = self.udisks_client.get_object(backing_object_path)
                if not backing_udisks_object.get_loop():
                    tcrypt_devices.append(Device(self, volume, udisks_object, backing_udisks_object))

            if self.udisks_object_is_tcrypt(udisks_object):
                tcrypt_devices.append(Device(self, volume, udisks_object))

        return tcrypt_devices

