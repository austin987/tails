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
"""Tails Greeter configuration"""

import os.path

# default Tails credentials
LPASSWORD = 'live'
LUSER = 'amnesia'

# data path
data_path = '/usr/share/tails-greeter/'

# File where supported language codes (such as en_US) are stored
# while building the tails-greeter binary package
language_codes_path = os.path.join(data_path, 'language_codes')

# File where default language code for languages are stored
default_langcodes_path = os.path.join(data_path, 'default_langcodes')

# Locales path
locales_path = '/usr/share/locale/'

# File where session locale settings are stored
locale_output_path = '/var/lib/gdm3/tails.locale'

# File where the session sudo password is stored
rootpassword_output_path = '/var/lib/gdm3/tails.password'

# World-readable file where Tails persistence status is stored
persistence_state_file = '/var/lib/live/config/tails.persistence'

# File where settings related to physical security are stored
physical_security_settings = '/var/lib/gdm3/tails.physical_security'
