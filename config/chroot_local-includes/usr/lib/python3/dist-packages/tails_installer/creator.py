# -*- coding: utf-8 -*-
#
# Copyright © 2008-2013  Red Hat, Inc. All rights reserved.
# Copyright © 2008-2013  Luke Macken <lmacken@redhat.com>
#
# This copyrighted material is made available to anyone wishing to use, modify,
# copy, or redistribute it subject to the terms and conditions of the GNU
# General Public License v.2.  This program is distributed in the hope that it
# will be useful, but WITHOUT ANY WARRANTY expressed or implied, including the
# implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.  You should have
# received a copy of the GNU General Public License along with this program; if
# not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth
# Floor, Boston, MA 02110-1301, USA. Any Red Hat trademarks that are
# incorporated in the source code or documentation are not subject to the GNU
# General Public License and may only be used or replicated with the express
# permission of Red Hat, Inc.

"""
Our main Tails Installer module.

This contains the TailsInstallerCreator class,
that provides platform-specific implementation
for Linux
"""

import subprocess
import tempfile
import logging
import shutil
import signal
import time
import os
import re
import stat
import sys

from io import StringIO
from datetime import datetime
from pprint import pformat

import gi
gi.require_version('UDisks', '2.0')
from gi.repository import UDisks, GLib  # NOQA: E402

from tails_installer.utils import (_move_if_exists,  # NOQA: E402
                                   _unlink_if_exists, bytes_to_unicode,
                                   unicode_to_filesystemencoding,
                                   _set_liberal_perms_recursive,
                                   underlying_physical_device,
                                   write_to_block_device, mebibytes_to_bytes,
                                   TailsError)
from tails_installer import _  # NOQA: E402
from tails_installer.config import CONFIG  # NOQA: E402

SYSTEM_PARTITION_FLAGS = [0,    # system partition
                          2,    # legacy BIOS bootable
                          60,   # read-only
                          62,   # hidden
                          63    # do not automount
                          ]
# EFI System Partition
ESP_GUID = 'C12A7328-F81F-11D2-BA4B-00A0C93EC93B'


class TailsInstallerError(TailsError):
    """ A generic error message that is thrown by the Tails Installer"""
    pass


class TailsInstallerCreator(object):
    """ An OS-independent parent class for Tails Installer Creators """

    min_installation_device_size = CONFIG['min_installation_device_size']
    source = None       # the object representing our live source image
    label = CONFIG['branding']['partition_label']  # if one doesn't exist
    fstype = None  # the format of our usb stick
    drives = {}  # {device: {'label': label, 'mount': mountpoint}}
    overlay = 0  # size in mb of our persisten overlay
    dest = None  # the mount point of of our selected drive
    uuid = None  # the uuid of our selected drive
    pids = []  # a list of pids of all of our subprocesses
    output = StringIO()  # log subprocess output in case of errors
    totalsize = 0  # the total size of our overlay + iso
    _drive = None  # mountpoint of the currently selected drive
    mb_per_sec = 0  # how many megabytes per second we can write
    log = None
    ext_fstypes = set(['ext2', 'ext3', 'ext4'])
    valid_fstypes = set(['vfat', 'msdos']) | ext_fstypes

    drive = property(fget=lambda self: self.drives[self._drive],
                     fset=lambda self, d: self._set_drive(d))

    def __init__(self, opts):
        self.opts = opts
        self._error_log_filename = self._setup_error_log_file()
        self._setup_logger()
        self.valid_fstypes -= self.ext_fstypes
        self.drives = {}
        self._udisksclient = UDisks.Client.new_sync()

    def _setup_error_log_file(self):
        temp = tempfile.NamedTemporaryFile(mode='a', delete=False,
                                           prefix='tails-installer-')
        temp.close()
        return temp.name

    def _setup_logger(self):
        self.log = logging.getLogger()
        self.log.setLevel(logging.DEBUG if self.opts.verbose else logging.INFO)

        formatter = logging.Formatter('%(asctime)s [%(filename)s:%(lineno)s (%(funcName)s)] %(levelname)s: %(message)s')

        self.stream_handler = logging.StreamHandler()
        self.stream_handler.setFormatter(formatter)
        self.log.addHandler(self.stream_handler)

        self.file_handler = logging.FileHandler(self._error_log_filename)
        self.file_handler.setFormatter(formatter)
        self.log.addHandler(self.file_handler)

    def detect_supported_drives(self, callback=None, force_partitions=False):
        """ Detect all supported (USB and SDIO) storage devices using UDisks.
        """
        mounted_parts = {}
        self.drives = {}
        for obj in self._udisksclient.get_object_manager().get_objects():
            block = obj.props.block
            self.log.debug('looking at %s' % obj.get_object_path())
            if not block:
                self.log.debug('skip %s which is not a block device'
                               % obj.get_object_path())
                continue
            partition = obj.props.partition
            filesystem = obj.props.filesystem
            drive = self._udisksclient.get_drive_for_block(block)
            if not drive:
                self.log.debug('skip %s which has no associated drive'
                               % obj.get_object_path())
                continue
            data = {
                'udi': obj.get_object_path(),
                'is_optical': drive.props.optical,
                'label': drive.props.id.replace(' ', '_'),
                'vendor': drive.props.vendor,
                'model': drive.props.model,
                'fstype': block.props.id_type,
                'fsversion': block.props.id_version,
                'uuid': block.props.id_uuid,
                'device': block.props.device,
                'mount': filesystem.props.mount_points if filesystem else None,
                'bootable': None,
                'parent': None,
                'parent_udi': None,
                'parent_size': None,
                'parent_data': None,
                'size': block.props.size,
                'mounted_partitions': set(),
                'is_device_big_enough_for_installation': True,
                'is_device_big_enough_for_upgrade': True,
                'is_device_big_enough_for_reinstall': True,
                'removable': drive.props.removable,
            }

            # Check non-removable drives
            if not data['removable']:
                self.log.debug('Skipping non-removable device: %s'
                               % data['device'])

            # Only pay attention to USB and SDIO devices, unless --force'd
            iface = drive.props.connection_bus
            if iface != 'usb' and iface != 'sdio' \
               and self.opts.force != data['device']:
                self.log.warning(
                    'Skipping device "%(device)s" connected to "%(interface)s" interface'
                    % {'device': data['udi'], 'interface': iface}
                )
                continue

            # Skip optical drives
            if data['is_optical'] and self.opts.force != data['device']:
                self.log.debug('Skipping optical device: %s' % data['device'])
                continue

            # Skip things without a size
            if not data['size'] and not self.opts.force:
                self.log.debug('Skipping device without size: %s'
                               % data['device'])
                continue

            if partition:
                partition_table = self._udisksclient.get_partition_table(
                    partition)
                parent_block = partition_table.get_object().props.block
                data['label'] = partition.props.name
                data['parent'] = parent_block.props.device
                data['parent_size'] = parent_block.props.size
                data['parent_udi'] = parent_block.get_object_path()
            else:
                parent_block = None

            # Check for devices that are too small. Note that we still
            # allow devices that can be upgraded for supporting legacy
            # installations.
            if not self.is_device_big_enough_for_installation(
                    data['parent_size']
                    if data['parent_size']
                    else data['size']):
                if not self.device_can_be_upgraded(data):
                    self.log.warning(
                        'Device is too small for installation: %s'
                        % data['device'])
                    data['is_device_big_enough_for_installation'] = False
                # Since reinstalling is a special case where full overitting
                # is done, the size of the device has to be bigger than
                # min_installation_device_size in all cases.
                data['is_device_big_enough_for_reinstall'] = False

            # To be more accurate we would need to either mount the candidate
            # device (which causes UX problems down the road) or to recursively
            # parse the output of fatcat.
            # We add a 5% margin to account for filesystem structures.
            if partition \
               and self.device_can_be_upgraded(data) \
               and hasattr(self, 'source') \
               and self.source is not None \
               and data['size'] < self.source.size * 1.05:
                self.log.warning(
                    'Device is too small for upgrade: %s'
                    % data['device'])
                data['is_device_big_enough_for_upgrade'] = False

            mount = data['mount']
            if mount:
                if len(mount) > 1:
                    self.log.warning('Multiple mount points for %s' %
                                     data['device'])
                mount = data['mount'] = data['mount'][0]
            else:
                mount = data['mount'] = None

            if parent_block and mount:
                if not data['parent'] in mounted_parts:
                    mounted_parts[data['parent']] = set()
                mounted_parts[data['parent']].add(data['udi'])

            data['free'] = mount \
                and self.get_free_bytes(mount) / 1024**2 \
                or None
            data['free'] = None  # XXX ?

            self.log.debug(pformat(data))

            if not force_partitions and self.opts.partition:
                if self.device_can_be_upgraded(data):
                    self.drives[data['device']] = data
                # Add whole drive in partitioning mode
                elif data['parent'] is None:
                    # Ensure the device is writable
                    if block.props.read_only:
                        self.log.debug(_('Unable to write on %(device)s, skipping.')
                                       % {'device': data['device']})
                        continue
                    self.drives[data['device']] = data
            else:
                if self.device_is_isohybrid(data):
                    if data['parent']:
                        # We will target the parent instead
                        continue
                self.drives[data['device']] = data

        # Remove parent drives if a valid partition exists.
        # This is always made to avoid listing both the devices
        # and their parents in the gui dropdown list.
        # But we keep the parent data in case of a reinstallation.
        drives_to_delete = set()
        for d in list(self.drives.values()):
            parent = d['parent']
            if parent is not None and parent in self.drives:
                self.drives[d['device']]['parent_data'] = self.drives[parent].copy()
                drives_to_delete.add(parent)
        for d in drives_to_delete:
            del self.drives[d]

        self.log.debug(pformat(mounted_parts))

        for device, data in self.drives.items():
            if self.source \
               and self.source.dev and data['udi'] == self.source.dev:
                continue
            if device in mounted_parts and len(mounted_parts[device]) > 0:
                data['mounted_partitions'] = mounted_parts[device]
                self.log.debug(_(
                    'Some partitions of the target device %(device)s are mounted. '
                    'They will be unmounted before starting the '
                    'installation process.') % {'device': data['device']})

        if callback:
            callback()

    def extract_iso(self):
        """ Extract our ISO with 7-zip directly to the USB key """
        self.log.info(_('Extracting live image to the target device...'))
        start = datetime.now()
        self.source.clone(self.dest)
        delta = datetime.now() - start
        if delta.seconds:
            self.mb_per_sec = (self.source.size / delta.seconds) / 1024**2
            if self.mb_per_sec:
                self.log.info(_('Wrote to device at %(speed)d MB/sec') % {
                    'speed': self.mb_per_sec})

    def syslinux_options(self):
        opts = []
        if self.opts.force:
            opts.append('-f')
        if self.opts.safe:
            opts.append('-s')
        return opts

    def _set_partition_flags(self, partition, flags):
        flags_total = 0
        for flag in flags:
            flags_total |= (1 << flag)
        partition.call_set_flags_sync(flags_total,
                                      GLib.Variant('a{sv}', None),
                                      None)

    def system_partition_size(self, device_size_in_bytes):
        """ Return the optimal system partition size (in bytes) for
        a device_size_in_bytes bytes large destination device: 4 GiB on devices
        smaller than 16000 MiB, 8 GiB otherwise.
        """
        # 1. Get unsupported cases out of the way
        if device_size_in_bytes \
           < mebibytes_to_bytes(self.min_installation_device_size):
            raise NotImplementedError
        # 2. Handle supported cases (note: you might be surprised if
        # you looked at the actual size of USB sticks labeled "16 GB"
        # in the real world, hence the weird definition of "16 GB"
        # used below)
        elif device_size_in_bytes >= mebibytes_to_bytes(14500):
            return mebibytes_to_bytes(8 * 1024)
        else:
            return mebibytes_to_bytes(4 * 1024)

    def is_device_big_enough_for_installation(self, device_size_in_bytes):
        return (
            device_size_in_bytes
            >= mebibytes_to_bytes(self.min_installation_device_size)
        )

    def can_read_partition_table(self, device=None):
        if not device:
            device = self.drive['device']

        proc = self.popen(['/sbin/sgdisk', '--print', device],
                          shell=False, passive=True)
        if proc.returncode:
            return False
        return True

    def clear_all_partition_tables(self, device=None):
        if not device:
            device = self.drive['device']

        # We need to ignore errors because sgdisk returns error code
        # 2 when it successfully zaps partition tables it cannot
        # understand... while we want to make it do this reset
        # precisely to fix that unreadable partition table issue.
        # Chicken'n'egg, right.
        self.popen(['/sbin/sgdisk', '--zap-all', device],
                   shell=False, passive=True)

    def popen(self, cmd, passive=False, ret='proc', **user_kwargs):
        """ A wrapper method for running subprocesses.

        This method handles logging of the command and it's output, and keeps
        track of the pids in case we need to kill them.  If something goes
        wrong, an error log is written out and a TailsInstallerError is thrown.

        @param cmd: The commandline to execute.  Either a string or a list.
        @param passive: Enable passive process failure.
        @param kwargs: Extra arguments to pass to subprocess.Popen
        """
        if isinstance(cmd, list):
            cmd_str = ' '.join(cmd)
        else:
            cmd_str = cmd
        self.log.debug(cmd_str)
        self.output.write(cmd_str)
        kwargs = {'shell': True, 'stdin': subprocess.PIPE}
        kwargs.update(user_kwargs)
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                **kwargs)
        self.pids.append(proc.pid)
        out, err = proc.communicate()
        out = bytes_to_unicode(out)
        err = bytes_to_unicode(err)
        self.output.write(out + '\n' + err + '\n')
        if proc.returncode:
            if passive:
                self.log.debug(self.output.getvalue())
            else:
                self.log.info(self.output.getvalue())
                raise TailsInstallerError(_(
                        'There was a problem executing the following command: `%(command)s`.\nA more detailed error log has been written to "%(filename)s".')
                        % {'command': cmd, 'filename': self._error_log_filename})
        if ret == 'stdout':
            return out
        return proc

    def check_free_space(self):
        """ Make sure there is enough space for the LiveOS and overlay """
        freebytes = self.get_free_bytes()
        self.log.debug('freebytes = %d' % freebytes)
        self.log.debug('source size = %d' % self.source.size)
        overlaysize = self.overlay * 1024**2
        self.log.debug('overlaysize = %d' % overlaysize)
        self.totalsize = overlaysize + self.source.size
        if self.totalsize > freebytes:
            raise TailsInstallerError(_(
                "Not enough free space on device." +
                "\n%(iso_size)dMB ISO + %(overlay_size)dMB overlay " +
                "> %(free_space)dMB free space") %
                {'iso_size': self.source.size/1024**2,
                 'overlay_size': self.overlay,
                 'free_space': freebytes/1024**2})

    def create_persistent_overlay(self):
        if self.overlay:
            self.log.info(_('Creating %sMB persistent overlay') % self.overlay)
            if self.fstype == 'vfat':
                # vfat apparently can't handle sparse files
                self.popen('dd if=/dev/zero of="%s" count=%d bs=1M'
                           % (self.get_overlay(), self.overlay))
            else:
                self.popen('dd if=/dev/zero of="%s" count=1 bs=1M seek=%d'
                           % (self.get_overlay(), self.overlay))

    def _update_configs(self, infile, outfile):
        outfile_new = '%s.new' % outfile
        shutil.copy(infile, outfile_new)
        infile = open(infile, 'r')
        outfile_new = open(outfile_new, 'w')
        usblabel = self.uuid and 'UUID=' + self.uuid or 'LABEL=' + self.label
        for line in infile.readlines():
            line = re.sub('/isolinux/', '/syslinux/', line)
            outfile_new.write(line)
        infile.close()
        outfile_new.close()
        shutil.move(outfile_new.name, outfile)

    def update_configs(self):
        """ Generate our syslinux.cfg and grub.conf files """
        grubconf = self.get_liveos_file_path('EFI', 'BOOT', 'grub.conf')
        bootconf = self.get_liveos_file_path('EFI', 'BOOT', 'boot.conf')
        bootx64conf = self.get_liveos_file_path('EFI', 'BOOT', 'bootx64.conf')
        bootia32conf = self.get_liveos_file_path('EFI', 'BOOT', 'bootia32.conf')
        updates = [(self.get_liveos_file_path('isolinux', 'isolinux.cfg'),
                    self.get_liveos_file_path('isolinux', 'syslinux.cfg')),
                   (self.get_liveos_file_path('isolinux', 'stdmenu.cfg'),
                    self.get_liveos_file_path('isolinux', 'stdmenu.cfg')),
                   (self.get_liveos_file_path('isolinux', 'exithelp.cfg'),
                    self.get_liveos_file_path('isolinux', 'exithelp.cfg')),
                   (self.get_liveos_file_path('EFI', 'BOOT', 'isolinux.cfg'),
                    self.get_liveos_file_path('EFI', 'BOOT', 'syslinux.cfg')),
                   (grubconf, bootconf)]
        copies = [(bootconf, grubconf),
                  (bootconf, bootx64conf),
                  (bootconf, bootia32conf)]

        for (infile, outfile) in updates:
            if os.path.exists(infile):
                self._update_configs(infile, outfile)
        # only copy/overwrite files we had originally started with
        for (infile, outfile) in copies:
            if os.path.exists(outfile):
                try:
                    shutil.copyfile(infile, outfile)
                except Exception as e:
                    self.log.warning(_('Unable to copy %(infile)s to %(outfile)s: %(message)s')
                                     % {'infile': infile,
                                        'outfile': outfile,
                                        'message': str(e)})

        syslinux_path = self.get_liveos_file_path('syslinux')
        _move_if_exists(self.get_liveos_file_path('isolinux'), syslinux_path)
        _unlink_if_exists(os.path.join(syslinux_path, 'isolinux.cfg'))

    def delete_liveos(self):
        """ Delete the files installed by the existing Live OS, after
        chmod'ing them since Python for Windows is unable to delete
        read-only files.
        """
        self.log.info(_('Removing existing Tails system'))
        for path in self.get_liveos_toplevel_files(absolute=True):
            if not os.path.exists(path):
                continue
            self.log.debug('Considering ' + path)
            if os.path.isfile(path):
                try:
                    os.unlink(path)
                except Exception as e:
                    raise TailsInstallerError(_(
                        "Unable to remove file from"
                        " previous Tails system: %(message)s") %
                       {'message': str(e)})
            elif os.path.isdir(path):
                try:
                    _set_liberal_perms_recursive(path)
                except OSError as e:
                    self.log.debug(_("Unable to chmod %(file)s: %(message)s")
                                   % {'file': path,
                                      'message': str(e)})
                try:
                    shutil.rmtree(path)
                except OSError as e:
                    raise TailsInstallerError(_(
                        "Unable to remove directory from"
                        " previous Tails system: %(message)s") %
                        {'message': str(e)})

    def get_liveos(self):
        return self.get_liveos_file_path(CONFIG['main_liveos_dir'])

    def running_liveos_mountpoint(self):
        return CONFIG['running_liveos_mountpoint']

    def get_liveos_file_path(self, *args):
        """ Given a path relative to the root of the Live OS filesystem,
        returns the absolute path to it from the perspective of the system
        tails-installer is running on.
        """
        return os.path.join(self.dest + os.path.sep, *args)

    def get_liveos_toplevel_files(self, absolute=False):
        """ Returns the list of files install at top level in the Live
        OS filesystem.
        If absolute=True, return absolute paths from the perspective
        of the system tails-installer is running on; else, return paths
        relative to the root of the Live OS filesystem.
        """
        toplevels = CONFIG['liveos_toplevel_files']
        if absolute:
            return [self.get_liveos_file_path(f) for f in toplevels]
        return toplevels

    def existing_overlay(self):
        return os.path.exists(self.get_overlay())

    def get_overlay(self):
        return os.path.join(self.get_liveos(),
                            'overlay-%s-%s' % (self.label, self.uuid or ''))

    def _set_drive(self, drive):
        # XXX: sometimes fails with:
        # Traceback (most recent call last):
        #  File "tails-installer/git/tails_installer.gui.py", line 200, in run
        #    self.live.switch_drive_to_system_partition()
        #  File "tails-installer/git/tails_installer.creator.py", line 967, in switch_drive_to_system_partition
        #    self.drive = '%s%s' % (full_drive_name, append)
        #  File "tails-installer/git/tails_installer.creator.py", line 88, in <lambda>
        #    fset=lambda self, d: self._set_drive(d))
        #  File "tails-installer/git/tails_installer.creator.py", line 553, in _set_drive
        #    raise TailsInstallerError(_('Cannot find device %s') % drive)
        if drive not in self.drives:
            raise TailsInstallerError(_('Cannot find device %s') % drive)
        self.log.debug('%s selected: %s' % (drive, self.drives[drive]))
        self._drive = drive
        self.uuid = self.drives[drive]['uuid']
        self.fstype = self.drives[drive]['fstype']

    def running_device(self):
        """Returns the physical block device UDI (e.g.
        /org/freedesktop/UDisks2/devices/sdb) from which the system
        is running."""
        liveos_mountpoint = self.running_liveos_mountpoint()
        if os.path.exists(liveos_mountpoint):
            return underlying_physical_device(liveos_mountpoint)

    def _storage_bus(self, dev):
        storage_bus = None
        try:
            storage_bus = dev.GetProperty('storage.bus')
        except Exception as e:
            self.log.exception(e)
        return storage_bus

    def _block_is_volume(self, dev):
        is_volume = False
        try:
            is_volume = dev.GetProperty('block.is_volume')
        except Exception as e:
            self.log.exception(e)
        return is_volume

    def _add_device(self, dev, parent=None):
        mount = str(dev.GetProperty('volume.mount_point'))
        device = str(dev.GetProperty('block.device'))
        if parent:
            parent = parent.GetProperty('block.device')
        self.drives[device] = {
            'label': str(dev.GetProperty('volume.label')).replace(' ', '_'),
            'fstype': str(dev.GetProperty('volume.fstype')),
            'fsversion': str(dev.GetProperty('volume.fsversion')),
            'uuid': str(dev.GetProperty('volume.uuid')),
            'mount': mount,
            'udi': dev,
            'free': mount and self.get_free_bytes(mount) / 1024**2 or None,
            'device': device,
            'parent': parent
        }

    def mount_device(self):
        """ Mount our device if it is not already mounted """
        if not self.fstype:
            raise TailsInstallerError(_('Unknown filesystem.  Your device '
                                        'may need to be reformatted.'))
        if self.fstype not in self.valid_fstypes:
            raise TailsInstallerError(_('Unsupported filesystem: %s') %
                                      self.fstype)
        self.dest = self.drive['mount']
        if not self.dest:
            self.log.debug('Mounting %s' % self.drive['udi'])
            # XXX: this is racy and then it sometimes fails with:
            # 'NoneType' object has no attribute 'call_mount_sync'
            filesystem = self._get_object().props.filesystem
            mount = None
            try:
                mount = filesystem.call_mount_sync(
                    arg_options=GLib.Variant('a{sv}', None),
                    cancellable=None)
            except GLib.Error as e:
                if 'org.freedesktop.UDisks2.Error.AlreadyMounted' in e.message:
                    self.log.debug('Device already mounted')
                else:
                    raise TailsInstallerError(_(
                        'Unknown GLib exception while trying to '
                        'mount device: %(message)s') %
                       {'message': str(e)})
            except Exception as e:
                raise TailsInstallerError(_(
                    'Unable to mount device: %(message)s') %
                   {'message': str(e)})

            # Get the new mount point
            if not mount:
                self.log.error(_('No mount points found'))
            else:
                self.dest = self.drive['mount'] = mount
                self.drive['free'] = self.get_free_bytes(self.dest) / 1024**2
                self.log.debug('Mounted %s to %s ' % (self.drive['device'],
                                                      self.dest))
        else:
            self.log.debug('Using existing mount: %s' % self.dest)

    def unmount_device(self):
        """ Unmount our device """
        self.log.debug(_('Entering unmount_device for "%(device)s"') %
                       {'device': self.drive['device']})

        self.log.debug(pformat(self.drive))
        if self.drive['mount'] is None:
            udis = self.drive['mounted_partitions']
        else:
            udis = [self.drive['udi']]
        if udis:
            self.log.info(_('Unmounting mounted filesystems on "%(device)s"') %
                          {'device': self.drive['device']})

        for udi in udis:
            self.log.debug(_('Unmounting "%(udi)s" on "%(device)s"') % {
                'device': self.drive['device'],
                'udi': udi
            })
            filesystem = self._get_object(udi).props.filesystem
            filesystem.call_unmount_sync(
                    arg_options=GLib.Variant('a{sv}', None),
                    cancellable=None)
        self.drive['mount'] = None
        if not self.opts.partition and self.dest is not None \
           and os.path.exists(self.dest):
            self.log.error(_('Mount %s exists after unmounting') % self.dest)
        self.dest = None
        # Sometimes the device is still considered as busy by the kernel
        # at this point, which prevents, when called by reset_mbr() ->
        # write_to_block_device() -> get_open_write_fd()
        # -> call_open_for_restore_sync() from opening it for writing.
        self.flush_buffers(silent=True)
        time.sleep(3)

    def partition_device(self):
        if not self.opts.partition:
            return

        self.log.info(_('Partitioning device %(device)s') % {
            'device': self.drive['device']
        })

        self.log.debug('Creating partition table')
        # Use udisks instead of plain sgdisk will allow unprivileged users
        # to get a refreshed partition table from the kernel
        for attempt in [1, 2]:
            try:
                self._get_object().props.block.call_format_sync(
                    'gpt',
                    arg_options=GLib.Variant('a{sv}', None),
                    cancellable=None)
            except GLib.Error as e:
                if attempt > 1:
                    raise
                # XXX: sometimes retrying fails as well
                # https://bugs.freedesktop.org/show_bug.cgi?id=76178
                if ('GDBus.Error:org.freedesktop.UDisks2.Error.Failed' in e.message and
                    'Error synchronizing after initial wipe' in e.message):
                    self.log.debug('Failed to synchronize. Trying again, which usually solves the issue. Error was: %s' % e.message)
                    self.flush_buffers(silent=True)
                    time.sleep(5)

        self.log.debug('Creating partition')
        partition_table = self._get_object().props.partition_table
        try:
            partition_table.call_create_partition_sync(
                    arg_offset=0,
                    arg_size=self.system_partition_size(
                        self.drive['parent_size']
                        if self.drive['parent_size']
                        else self.drive['size']),
                    arg_type=ESP_GUID,
                    arg_name=self.label,
                    arg_options=GLib.Variant('a{sv}', None),
                    cancellable=None)
        except GLib.Error as e:
            # XXX: as of Debian Jessie, we often get errors while wiping
            # (Debian bug #767457). We ignore them as they are not fatal
            # for us... but we need to fix a few things later...
            if ('GDBus.Error:org.freedesktop.UDisks2.Error.Failed' in e.message and
                    'Error wiping newly created partition' in e.message):
                self.log.debug('Ignoring error %s' % e.message)
            else:
                raise

        # Get a fresh system_partition object, otherwise
        # _set_partition_flags sometimes fails with
        # 'GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: No
        # such interface 'org.freedesktop.UDisks2.Partition' on object
        # at path /org/freedesktop/UDisks2/block_devices/sda1'
        self.rescan_block_device(self._get_object().props.block)
        system_partition = self.first_partition(self.drive['udi'])

        self._set_partition_flags(system_partition, SYSTEM_PARTITION_FLAGS)

        # Get a fresh system_partition object, otherwise
        # call_set_flags_sync sometimes fails with 'No such interface
        # 'org.freedesktop.UDisks2.Partition' on object at path
        # /org/freedesktop/UDisks2/block_devices/sdd1'
        # (https://gitlab.tails.boum.org/tails/tails/-/issues/15432)
        self.rescan_block_device(self._get_object().props.block)
        system_partition = self.first_partition(self.drive['udi'])

        # Give the system some more time to recognize the updated
        # partition, otherwise sometimes later on, when
        # switch_drive_to_system_partition is called, it calls
        # _set_drive, that fails with 'Cannot find device /dev/sda1'.
        self.rescan_block_device(self._get_object().props.block)

    def is_partition_GPT(self, drive=None):
        # Check if the partition scheme is GPT
        if drive:
            obj = self._get_object(drive['udi'])
        else:
            obj = self._get_object()

        # First check if we actually have found the object
        if obj is None:
            return False
        # and then if it has a partition
        if not obj.props.partition:
            return False

        partition_table = obj.props.partition_table
        if not partition_table:
            partition_table = self._udisksclient.get_partition_table(obj.props.partition)
        if partition_table.props.type == 'gpt':
            return True
        else:
            return False

    def device_can_be_upgraded(self, device_data=None):
        # Checks that device already has Tails installed
        if not device_data:
            device = self.drive
        else:
            device = device_data
        return not self.device_is_isohybrid(device) \
            and self.is_partition_GPT(device) \
            and device['fstype'] == 'vfat' \
            and device['label'] == 'Tails'

    def device_is_isohybrid(self, drive=None):
        if not drive:
            device = self.drive
        else:
            device = drive
        return device['fstype'] == 'iso9660'

    def save_full_drive(self):
        self._full_drive = self.drives[self._drive]

    def switch_drive_to_system_partition(self):
        full_drive_name = self._full_drive['device']
        append = False
        if full_drive_name.startswith('/dev/sd'):
            append = '1'
        elif full_drive_name.startswith('/dev/mmcblk'):
            append = 'p1'
        if not append:
            self.log.warning(
                _("Unsupported device '%(device)s', please report a bug.") %
                {'device': full_drive_name}
            )
            self.log.info(_('Trying to continue anyway.'))
            append = '1'
        self.drive = '%s%s' % (full_drive_name, append)

    def switch_back_to_full_drive(self):
        self.drives[self._full_drive['device']] = self._full_drive
        self.drive = self._full_drive['device']

    def verify_filesystem(self):
        self.log.info(_('Verifying filesystem...'))
        if self.fstype not in self.valid_fstypes:
            if not self.fstype:
                raise TailsInstallerError(_('Unknown filesystem.  Your device '
                                            'may need to be reformatted.'))
            else:
                raise TailsInstallerError(_("Unsupported filesystem: %s") %
                                          self.fstype)
        if self.drive['label'] != self.label:
            self.log.info('Setting %(device)s label to %(label)s' %
                          {'device': self.drive['device'],
                           'label': self.label})
            try:
                if self.fstype in ('vfat', 'msdos'):
                    try:
                        self.popen('/sbin/dosfslabel %s %s' % (
                                   self.drive['device'], self.label))
                    except TailsInstallerError:
                        # dosfslabel returns an error code even upon success
                        pass
                else:
                    self.popen('/sbin/e2label %s %s' % (self.drive['device'],
                                                        self.label))
            except TailsInstallerError as e:
                self.log.error(_("Unable to change volume label: %(message)s") %
                               {'message': str(e)})

    def install_bootloader(self):
        """ Run syslinux to install the bootloader on our devices """
        self.log.info(_('Installing bootloader...'))

        # Don't prompt about overwriting files from mtools (#491234)
        for ldlinux in [self.get_liveos_file_path(p, 'ldlinux.sys')
                        for p in ('syslinux', '')]:
            self.log.debug('Looking for %s' % ldlinux)
            if os.path.isfile(ldlinux):
                self.log.debug(_('Removing %(file)s') % {'file': ldlinux})
                os.unlink(ldlinux)

        # FAT
        syslinux_executable = 'syslinux';
        self.log.debug('Will use %s as the syslinux binary'
                       % syslinux_executable)
        iso_syslinux = self.get_liveos_file_path('utils', 'linux',
                                                 syslinux_executable)
        tmpdir = tempfile.mkdtemp()
        tmp_syslinux = os.path.join(tmpdir, syslinux_executable)
        shutil.copy(iso_syslinux, tmp_syslinux)
        os.chmod(tmp_syslinux,
                 os.stat(tmp_syslinux).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
        self.flush_buffers()
        self.unmount_device()
        self.popen('%s %s -d %s %s' % (
                tmp_syslinux,
                ' '.join(self.syslinux_options()),
                'syslinux', self.drive['device']),
                   env={"LC_CTYPE": "C"})
        shutil.rmtree(tmpdir)

    def get_free_bytes(self, device=None):
        """ Return the number of available bytes on our device """
        device = device and device or self.dest
        if device is None:
            return None
        try:
            (f_bsize, f_frsize, f_blocks, f_bfree, f_bavail, f_files, f_ffree, f_favail, f_flag, f_namemax) = os.statvfs(device)
            return f_bsize * f_bavail
        except Exception as e:
            print('device', device, 'self.dest', self.dest, file=sys.stderr)
            raise e

    def _get_object(self, udi=None):
        """Return an UDisks.Object for our drive"""
        if not udi:
            udi = self.drive['udi']
        return self._udisksclient.get_object(udi)

    def first_partition(self, udi=None):
        """Return the UDisks2.Partition object for the first partition on the drive"""
        if not udi:
            udi = self.drive['udi']
        obj = self._get_object(udi)
        partition_table = obj.props.partition_table
        partitions = self._udisksclient.get_partitions(partition_table)
        return partitions[0]

    def terminate(self):
        for pid in self.pids:
            try:
                os.kill(pid, signal.SIGHUP)
                self.log.debug('Killed process %d' % pid)
            except OSError as e:
                self.log.debug(str(e))
        if os.path.exists(self._error_log_filename):
            if not os.path.getsize(self._error_log_filename):
                # We don't want any failure here to block other tear down tasks
                try:
                    os.unlink(self._error_log_filename)
                except:
                    print('Could not delete log file.', file=sys.stderr)

    def bootable_partition(self):
        """ Ensure that the selected partition is flagged as bootable """
        if self.opts.partition:
            # already done at partitioning step
            return
        if self.drive.get('parent') is None:
            self.log.debug('No partitions on device; not attempting to mark '
                           'any partitions as bootable')
            return
        import parted
        try:
            disk, partition = self.get_disk_partition()
        except TailsInstallerError as e:
            self.log.exception(e)
            return
        if partition.isFlagAvailable(parted.PARTITION_BOOT):
            if partition.getFlag(parted.PARTITION_BOOT):
                self.log.debug(_('%s already bootable') % self._drive)
            else:
                partition.setFlag(parted.PARTITION_BOOT)
                try:
                    disk.commit()
                    self.log.info('Marked %s as bootable' % self._drive)
                except Exception as e:
                    self.log.exception(e)
        else:
            self.log.warning('%s does not have boot flag' % self._drive)

    def get_disk_partition(self):
        """ Return the PedDisk and partition of the selected device """
        import parted
        parent = self.drives[self._drive]['parent']
        dev = parted.Device(path=parent)
        disk = parted.Disk(device=dev)
        for part in disk.partitions:
            if self._drive == '/dev/%s' % (part.getDeviceNodeName(),):
                return disk, part
        raise TailsInstallerError(_('Unable to find partition'))

    def initialize_zip_geometry(self):
        """ This method initializes the selected device in a zip-like fashion.

        :Note: This feature is currently experimental, and will DESTROY ALL DATA
               on your device!

        More details on this can be found here:
            http://syslinux.zytor.com/doc/usbkey.txt
        """
        self.log.info('Initializing %s in a zip-like fashon' % self._drive)
        heads = 64
        cylinders = 32
        self.popen('/usr/lib/syslinux/mkdiskimage -4 %s 0 %d %d' % (
                   self._drive[:-1], heads, cylinders))

    def format_device(self):
        """ Format the selected partition as FAT32 """
        self.log.info(_('Formatting %(device)s as FAT32') % {'device': self._drive})
        dev = self._get_object()
        block = dev.props.block
        try:
            block.call_format_sync(
                'vfat',
                arg_options=GLib.Variant(
                    'a{sv}',
                    {'label': GLib.Variant('s', self.label),
                     'update-partition-type': GLib.Variant('s', 'FALSE')}))
        except GLib.Error as e:
            if ('GDBus.Error:org.freedesktop.UDisks2.Error.Failed' in e.message and
                ('Error synchronizing after formatting' in e.message
                 or 'Error synchronizing after initial wipe' in e.message)):
                self.log.debug('Failed to synchronize. Trying again, which usually solves the issue. Error was: %s' % e.message)
                self.flush_buffers(silent=True)
                time.sleep(5)
                block.call_format_sync(
                    'vfat',
                    arg_options=GLib.Variant(
                        'a{sv}',
                        {'label': GLib.Variant('s', self.label),
                         'update-partition-type': GLib.Variant('s', 'FALSE')}))
            else:
                raise

        self.fstype = self.drive['fstype'] = 'vfat'
        self.flush_buffers(silent=True)
        time.sleep(3)
        self._get_object().props.block.call_rescan_sync(GLib.Variant('a{sv}', None))

    def get_mbr(self):
        parent = self.drive.get('parent', self._drive)
        if parent is None:
            parent = self._drive
        parent = str(parent)
        self.log.debug('Checking the MBR of %s' % parent)
        drive = open(parent, 'rb')
        mbr = ''.join(['%02X' % ord(x) for x in drive.read(2)])
        drive.close()
        self.log.debug('mbr = %r' % mbr)
        return mbr

    def blank_mbr(self):
        """ Return whether the MBR is empty or not """
        return self.get_mbr() == '0000'

    def _get_mbr_bin(self):
        # We install syslinux' gptmbr.bin as mbr.bin there, for
        # compatibility with paths used by Tuxboot and possibly others
        return self.get_liveos_file_path('utils', 'mbr', 'mbr.bin')

    def mbr_matches_syslinux_bin(self):
        """
        Return whether or not the MBR on the drive matches the syslinux
        gptmbr.bin found in the system being installed
        """
        mbr_bin = open(self._get_mbr_bin(), 'rb')
        mbr = ''.join(['%02X' % ord(x) for x in mbr_bin.read(2)])
        return mbr == self.get_mbr()

    def read_extracted_mbr(self):
        mbr_path = self._get_mbr_bin()
        self.log.info(_('Reading extracted MBR from %s') % mbr_path)
        with open(mbr_path, 'rb') as mbr_fd:
            self.extracted_mbr_content = mbr_fd.read()
        if not len(self.extracted_mbr_content):
            raise TailsInstallerError(_("Could not read the extracted MBR from %(path)s")
                                      % {'path': mbr_path})

    def reset_mbr(self):
        parent = parent = self.drive.get('parent', self._drive)
        if parent is None:
            parent = self._drive
            parent_udi = self.drive['udi']
        else:
            parent_udi = self.drive['parent_udi']
        parent_udi = str(parent_udi)
        parent = str(parent)
        if '/dev/loop' not in self.drive:
            self.log.info(_('Resetting Master Boot Record of %s') % parent)
            self.log.debug(_('Resetting Master Boot Record of %s') % parent_udi)
            obj = self._get_object(udi=parent_udi)
            block = obj.props.block
            write_to_block_device(block, self.extracted_mbr_content)
        else:
            self.log.info(_('Drive is a loopback, skipping MBR reset'))

    def flush_buffers(self, silent=False):
        if not silent:
            self.log.info(_('Synchronizing data on disk...'))
        self.popen('sync')

    def rescan_block_device(self, block):
        self._udisksclient.settle()
        self.flush_buffers(silent=True)
        time.sleep(5)
        block.call_rescan_sync(GLib.Variant('a{sv}', None))

    def connect_drive_monitor(self, callback, data=None):
        self._udisksclient.connect('changed', callback, data)
