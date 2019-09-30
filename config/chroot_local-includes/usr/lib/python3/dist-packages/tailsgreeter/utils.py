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

import logging
import subprocess

import gi

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk                                   # NOQA: E402

# Mark translatable strings, but don't actually translate them, as we
# delegate this to TranslatableWindow that handles on-the-fly language changes
_ = lambda text: text   # NOQA: E731


def popover_toggle(popover):
    """Toggle the visibility of popover"""
    if popover.get_visible():
        popover.set_visible(False)
    else:
        popover.set_visible(True)


def get_on_off_string(value, default=None):
    """Return "On"|"Off" [" (default)"] based on value and default"""
    if value == default:
        if value:
            return _("On (default)")
        else:
            return _("Off (default)")
    else:
        if value:
            return _("On")
        else:
            return _("Off")


def import_builder_objects(cls, builder, names):
    """Import Gtk.Builder objects with names as attributes of cls"""
    for name in names:
        setattr(cls, name, builder.get_object(name))


def check_output_and_error(args, exception, error_message, stdin=None):
    """Launch a process checking its output and raising exception if needed

    Launch process with args, giving stdin as input, raising exception with
    error_message as exception message (replacing {returncode}, {stdout} and
    {stderr} with their values) and return its output.
    """
    proc = subprocess.Popen(
        args,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True
        )
    out, err = proc.communicate(stdin)
    if proc.returncode:
        logging.debug(error_message.format(
                returncode=proc.returncode, stdout=out, stderr=err)
            )
        raise exception(
            error_message.format(
                returncode=proc.returncode, stdout=out, stderr=err)
            )
    return out


def setting_id_from_row(row):
    """Return a setting id from a Gtk.ListRow

    The Gtk.ListRow should be named listboxrow_settings_<setting_id>.
    """
    if not row:
        return None
    else:
        row_id = Gtk.Buildable.get_name(row)
        return row_id.replace("listboxrow_", "")
