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
"""Root access handling

"""
import os
import os.path
import logging
import pipes

import tailsgreeter.config


class RootAccessSettings(object):
    """Model storing settings related to root access

    """
    def __init__(self):
        # Root password
        self.password = None
        # XXX: this should read the content of the setting file

    @property
    def password(self):
        return self._password

    @password.setter
    def password(self, password):
        self._password = password
        if password:
            with open(tailsgreeter.config.rootpassword_output_path, 'w') as f:
                os.chmod(tailsgreeter.config.rootpassword_output_path, 0o600)
                f.write('TAILS_USER_PASSWORD=%s\n'
                        % pipes.quote(self.password))
                logging.debug('password written to %s',
                              tailsgreeter.config.rootpassword_output_path)
        else:
            try:
                os.unlink(tailsgreeter.config.rootpassword_output_path)
                logging.debug('removed %s',
                              tailsgreeter.config.rootpassword_output_path)
            except OSError:
                if not os.path.exists(
                        tailsgreeter.config.rootpassword_output_path):
                    pass
                else:
                    raise
