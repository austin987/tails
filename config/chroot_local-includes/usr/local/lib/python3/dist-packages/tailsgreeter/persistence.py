# Copyright 2012-2016 Tails developers <tails@boum.org>
# Copyright 2011 Max <govnototalitarizm@gmail.com>
# Copyright 2011 Martin Owens
#
# This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#
"""Persistence handling

"""
import logging
import os

import gettext
_ = gettext.gettext

import tailsgreeter         # NOQA: E402
import tailsgreeter.config  # NOQA: E402
import tailsgreeter.errors  # NOQA: E402
import tailsgreeter.utils   # NOQA: E402


class PersistenceSettings(object):
    """Controller for settings related to persistence

    """
    def __init__(self):
        self.is_unlocked = False
        self.containers = []
        self.cleartext_name = 'TailsData_unlocked'
        self.cleartext_device = '/dev/mapper/' + self.cleartext_name

    def has_persistence(self):
        # FIXME: list_containers may raise exceptions. Deal with that.
        self.containers = [
            {"path": container, "locked": True}
            for container in self.list_containers()
            ]
        return len(self.containers)

    def unlock(self, passphrase, readonly=False):
        """Ask the backend to activate persistence and handle errors

        Returns: True if everything went fine, False if the user should try
        again."""
        logging.debug("Unlocking persistence")
        for container in self.containers:
            try:
                self.activate_container(
                    device=container['path'],
                    password=passphrase,
                    readonly=readonly)
                self.is_unlocked = True
                return True
            except tailsgreeter.errors.WrongPassphraseError:
                pass
        return False

    def lock(self):
        logging.debug("Locking persistence")
        try:
            self.unmount_persistence()
            self.lock_device()
            self.is_unlocked = False
            return True
        except tailsgreeter.errors.LivePersistError as e:
            logging.exception(e)
            return False

    def list_containers(self):
        """Returns a list of persistence containers we might want to unlock."""
        args = [
            "/usr/bin/sudo", "-n", "/usr/local/sbin/live-persist",
            "--log-file=/var/log/live-persist",
            "--encryption=luks",
            "list", "TailsData"
            ]
        out = tailsgreeter.utils.check_output_and_error(
            args,
            exception=tailsgreeter.errors.LivePersistError,
            error_message=_("live-persist failed with return code "
                            "{returncode}:\n"
                            "{stderr}")
            )
        containers = str.splitlines(out)
        logging.debug("found containers: %s", containers)
        return containers

    def activate_container(self, device, password, readonly):
        cleartext_device = self.unlock_device(device, password)
        logging.debug("unlocked cleartext_device: %s", cleartext_device)
        self.setup_persistence(cleartext_device, readonly)
        # This file must be world-readable so that software running
        # as LIVE_USERNAME or tails-persistence-setup can read it.
        with open(tailsgreeter.config.persistence_state_file, 'w') as f:
            os.chmod(tailsgreeter.config.persistence_state_file, 0o644)
            f.write('TAILS_PERSISTENCE_ENABLED=true\n')
            if readonly:
                f.write('TAILS_PERSISTENCE_READONLY=true\n')

    def unlock_device(self, device, password):
        """Unlock the LUKS persistent device"""
        if not os.path.exists(self.cleartext_device):
            args = [
                "/usr/bin/sudo", "-n",
                "/sbin/cryptsetup", "luksOpen",
                "--tries", "1",
                device, self.cleartext_name
                ]
            tailsgreeter.utils.check_output_and_error(
                args,
                stdin="{password}\n".format(password=password),
                exception=tailsgreeter.errors.WrongPassphraseError,
                error_message=_("cryptsetup failed with return code "
                                "{returncode}:\n"
                                "{stdout}\n{stderr}"))
            logging.debug("crytpsetup success")
        return self.cleartext_device

    def lock_device(self):
        """Unlock the LUKS persistent device"""
        if os.path.exists(self.cleartext_device):
            args = [
                "/usr/bin/sudo", "-n",
                "/sbin/cryptsetup", "luksClose",
                self.cleartext_name
                ]
            tailsgreeter.utils.check_output_and_error(
                args,
                exception=tailsgreeter.errors.LivePersistError,
                error_message=_("cryptsetup failed with return code "
                                "{returncode}:\n"
                                "{stdout}\n{stderr}")
                )

    def setup_persistence(self, cleartext_device, readonly):
        args = ["/usr/bin/sudo", "-n", "/usr/local/sbin/live-persist"]
        if readonly:
            args.append('--read-only')
        else:
            args.append('--read-write')
        args.append('--log-file=/var/log/live-persist')
        args.append('activate')
        args.append(cleartext_device)
        tailsgreeter.utils.check_output_and_error(
            args,
            exception=tailsgreeter.errors.LivePersistError,
            error_message=_("live-persist failed with return code "
                            "{returncode}:\n"
                            "{stdout}\n{stderr}")
            )

    def unmount_persistence(self):
        args = [
            "/usr/bin/sudo", "-n",
            "/bin/umount", "-A",
            self.cleartext_device
            ]
        tailsgreeter.utils.check_output_and_error(
            args,
            exception=tailsgreeter.errors.LivePersistError,
            error_message=_("umount failed with return code {returncode}:\n"
                            "{stdout}\n{stderr}")
                            )
