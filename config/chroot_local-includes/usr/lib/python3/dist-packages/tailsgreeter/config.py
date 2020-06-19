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
data_path = '/usr/share/tails/greeter/'

# File containing the locales for the supported languages
supported_locales_path = os.path.join(data_path, 'supported_locales')

# System locales directory
system_locale_dir = '/usr/share/locale/'

# Directory where the Greeter settings are stored
settings_dir = '/var/lib/gdm3/settings'

# Directory where the persistent Greeter settings are stored
persistent_settings_dir = '/var/lib/gdm3/settings/persistent'

# File where the session language setting is stored
language_setting_path = os.path.join(settings_dir, 'tails.language')

# File where the session formats setting is stored
formats_setting_path = os.path.join(settings_dir, 'tails.formats')

# File where the session keyboard setting is stored
keyboard_setting_path = os.path.join(settings_dir, 'tails.keyboard')

# File where the session sudo password is stored
admin_password_path = os.path.join(settings_dir, 'tails.password')

# File where the network setting is stored
network_setting_path = os.path.join(settings_dir, 'tails.network')

# File where the MAC address spoofing setting is stored
macspoof_setting_path = os.path.join(settings_dir, 'tails.macspoof')

# File where the unsafe browser setting is stored
unsafe_browser_setting_filename = 'tails.unsafe-browser'
unsafe_browser_setting_path = os.path.join(settings_dir, unsafe_browser_setting_filename)

# World-readable file where Tails persistence status is stored
persistence_state_file = '/var/lib/live/config/tails.persistence'
