"""Tails persistence related tests."""

import os
import subprocess

from tailslib import PERSISTENCE_SETUP_USERNAME
from tailslib.utils import launch_x_application


PERSISTENCE_DIR = "/live/persistence/TailsData_unlocked"
NEWLY_CREATED_PERSISTENCE_DIR = "/media/tails-persistence-setup/TailsData"
PERSISTENCE_PARTITION = "/dev/disk/by-partlabel/TailsData"


def get_persistence_path(search_new_persistence=False,
                         return_nonexistent=False):
    """Return the path of the (newly created) persistence.

    Return PERSISTENCE_DIR if it exists.  If search_new_persistence is True,
    also try NEWLY_CREATED_PERSISTENCE_DIR.

    If return_nonexistent is true, return the path that the file would have
    after new persistence creation.

    If no persistence directory exists and return_nonexistent is true, raise
    FileNotFoundError.
    """
    if os.path.isdir(PERSISTENCE_DIR):
        return PERSISTENCE_DIR
    elif search_new_persistence:
        if os.path.isdir(NEWLY_CREATED_PERSISTENCE_DIR) or return_nonexistent:
            return NEWLY_CREATED_PERSISTENCE_DIR
        else:
            raise FileNotFoundError(
                "No persistence directory found. Neither {dir} not {alt_dir} "
                "exist.".format(dir=PERSISTENCE_DIR,
                                alt_dir=NEWLY_CREATED_PERSISTENCE_DIR))
    else:
        raise FileNotFoundError(
            "No persistence directory found in {dir}".format(
                dir=PERSISTENCE_DIR))


def has_persistence():
    """Return true iff PERSISTENCE_PARTITION exists."""
    return os.path.exists(PERSISTENCE_PARTITION)


def has_unlocked_persistence(search_new_persistence=False):
    """Return true iff a persistence directory exists.

    The search_new_persistence argument is passed to get_persistence_path.
    """
    try:
        get_persistence_path(search_new_persistence)
    except FileNotFoundError:
        return False
    else:
        return True


def is_tails_media_writable():
    """Return true iff tails is started from a writable media."""
    return not subprocess.run(
        "/usr/local/lib/tails-boot-device-can-have-persistence").returncode


def launch_persistence_setup(*args):
    """Launch tails-persistence-setup and wait for its completion."""
    launch_x_application(PERSISTENCE_SETUP_USERNAME,
                         "/usr/bin/tails-persistence-setup",
                         *args)
