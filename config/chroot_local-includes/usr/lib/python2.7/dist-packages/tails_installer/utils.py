# -*- coding: utf-8 -*-

import os
import re
import subprocess
import shutil
import stat
import sys
from tails_installer import _
from tails_installer.config import config

from gi.repository import GLib

class TailsError(Exception):
    """ A generic Exception the allows us to manage error
        messages encoded in unicode """
    def __init__(self, message):
        encoded_message=unicode_to_utf8(message)
        super(TailsError, self).__init__(encoded_message)
        self.message = encoded_message

    def __unicode__(self):
        return self.message

def _to_unicode(obj, encoding='utf-8'):
    if hasattr(obj, 'toUtf8'): # PyQt4.QtCore.QString
        obj = str(obj.toUtf8())
    if isinstance(obj, basestring):
        if not isinstance(obj, unicode):
            obj = unicode(obj, encoding)
    return obj

def unicode_to_utf8(string):
    if isinstance(string, unicode):
        return string.encode('utf-8')
    return string

def unicode_to_filesystemencoding(string):
    if isinstance(string, unicode):
        return string.encode(sys.getfilesystemencoding(), 'replace')
    return string

def extract_file_content_from_iso(iso_path, path):
    """ Return the content of that file read from inside self.iso """

    cmd = ['isoinfo', '-R', '-i', unicode_to_utf8(iso_path),
           '-x', unicode_to_utf8(path)]

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    out = unicode_to_utf8(out)
    err = unicode_to_utf8(err)
    if proc.returncode:
        raise Exception(_("There was a problem executing `%s`."
                          "%s\n%s") % (cmd, out, err))
    return out

def iso_is_live_system(iso_path):
    """ Return true iff a Live system is detected inside the iso_path file """
    version = extract_file_content_from_iso(iso_path, '/.disk/info')
    return version.startswith('Debian GNU/Linux')

def _dir_size(source):
    total_size = os.path.getsize(source)
    for item in os.listdir(source):
        itempath = os.path.join(source, item)
        if os.path.isfile(itempath):
            total_size += os.path.getsize(itempath)
        elif os.path.isdir(itempath):
            total_size += _dir_size(itempath)
    return total_size

def _move_if_exists(src, dest):
    if os.path.exists(src):
        shutil.move(src, dest)

def _unlink_if_exists(path):
    if os.path.exists(path):
        os.unlink(path)

def _set_liberal_perms_recursive(destination):
    def _set_liberal_perms(arg, dirname, fnames):
        if dirname == 'lost+found':
            return
        os.chmod(dirname, 0755)
        for f in fnames:
            if f == 'lost+found':
                continue
            file = os.path.join(dirname, f)
            if os.path.isdir(file):
                os.chmod(file, 0755)
            elif os.path.isfile(file):
                os.chmod(file, 0644)
    os.path.walk(destination, _set_liberal_perms, None)

def underlying_physical_device(path):
    """ Returns the physical block device UDI on which the specified file is
    stored (e.g. /org/freedesktop/UDisks2/block_devices/sdb).
    """
    rawdev = os.stat(path)[stat.ST_DEV]
    from gi.repository import UDisks
    udisksclient = UDisks.Client.new_sync()
    block = udisksclient.get_block_for_dev(rawdev)
    drive = udisksclient.get_drive_for_block(block)
    parentblock = udisksclient.get_block_for_drive(drive, get_physical=False)
    return parentblock.get_object_path()

def _format_bytes_in_gb(value):
    return '%0.1f GB' % (value / 10.0**9)


def MiB_to_bytes(size_in_MiB):
    return size_in_MiB * 1024**2


def _get_datadir():
    script_path = os.path.abspath(sys.argv[0])
    if not script_path.startswith('/usr/'):
        if os.path.exists('data/tails-installer.ui'):
            return('data')
    else:
        return('/usr/share/tails-installer')

def get_open_write_fd(block):
    (fd_index, fd_list) = block.call_open_for_restore_sync(
        arg_options=GLib.Variant('a{sv}', None)
    )
    fd = fd_list.get(fd_index.get_handle())
    if fd == -1:
        raise Exception(_("Could not open device for writing."))
    return fd

def write_to_block_device(block, string):
    fd = get_open_write_fd(block)
    os.write(fd, string)
    os.fsync(fd)
    os.close(fd)
