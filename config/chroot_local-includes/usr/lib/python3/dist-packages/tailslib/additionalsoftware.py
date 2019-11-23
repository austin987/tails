"""Tails Additional Software configuration file management."""

import grp
import logging
import os
import os.path
import pwd
import re

import atomicwrites

from tailslib import PERSISTENCE_SETUP_USERNAME
from tailslib.persistence import get_persistence_path


PACKAGES_LIST_FILE = "live-additional-software.conf"


class ASPError(Exception):
    """Base class for exceptions raised by ASP."""


class ASPDataError(ASPError):
    """Raised when the data read does not have the expected format."""
    pass


def _write_config(packages, search_new_persistence=False):
    config_file_owner_uid = pwd.getpwnam(PERSISTENCE_SETUP_USERNAME).pw_uid
    config_file_owner_gid = grp.getgrnam(PERSISTENCE_SETUP_USERNAME).gr_gid

    packages_list_path = get_packages_list_path(search_new_persistence)
    try:
        os.setegid(config_file_owner_gid)
        os.seteuid(config_file_owner_uid)
        with atomicwrites.atomic_write(packages_list_path,
                                       overwrite=True) as f:
            for package in sorted(packages):
                f.write(package + '\n')
        os.chmod(packages_list_path, 0o0644)
    finally:
        os.seteuid(0)
        os.setegid(0)


def filter_package_details(pkg):
    """Filter target release, version and architecture from pkg."""
    return re.split("[/:=]", pkg)[0]


def get_packages_list_path(search_new_persistence=False,
                           return_nonexistent=False):
    """Return the package list file path in current or new persistence.

    The search_new_persistence and return_nonexistent arguments are passed to
    get_persistence_path.
    """
    persistence_dir = get_persistence_path(search_new_persistence,
                                           return_nonexistent)
    return os.path.join(persistence_dir, PACKAGES_LIST_FILE)


def get_additional_packages(search_new_persistence=False):
    """Return the list of all additional packages configured.

    The search_new_persistence argument is passed to get_persistence_path.
    """
    packages = set()
    try:
        with open(get_packages_list_path(search_new_persistence)) as f:
            for line in f:
                line = line.strip()
                if line:
                    packages.add(line)
    except FileNotFoundError:
        # Just return an empty set.
        pass
    return packages


def add_additional_packages(new_packages, search_new_persistence=False):
    """Add packages to additional packages configuration.

    Add the packages to additional packages configuration.

    The new_packages argument should be a list of packages names.
    The search_new_persistence argument is passed to get_persistence_path.
    """
    logging.info("Adding to additional packages list: %s" % new_packages)
    packages = get_additional_packages(search_new_persistence)
    # The list of packages was initially provided by apt after installing them,
    # so we don't check the names.
    packages |= new_packages

    _write_config(packages, search_new_persistence)


def remove_additional_packages(old_packages, search_new_persistence=False):
    """Remove packages from additional packages configuration.

    Removes the packages from additional packages configuration.

    The old_packages argument should be a list of packages names.
    The search_new_persistence argument is passed to get_persistence_path.
    """
    logging.info("Removing from additional packages list: %s" % old_packages)
    packages = get_additional_packages(search_new_persistence)
    # The list of packages was initially provided by apt after removing them,
    # so we don't check the names.
    packages -= old_packages

    _write_config(packages, search_new_persistence)
