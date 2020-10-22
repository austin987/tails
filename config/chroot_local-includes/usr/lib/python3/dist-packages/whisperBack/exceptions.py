#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

########################################################################
# WhisperBack - Send feedback in an encrypted mail
# Copyright (C) 2009-2018 Tails developers <tails@boum.org>
#
# This file is part of WhisperBack
#
# WhisperBack is  free software; you can redistribute  it and/or modify
# it under the  terms of the GNU General Public  License as published by
# the Free Software Foundation; either  version 3 of the License, or (at
# your option) any later version.
# 
# This program  is distributed in the  hope that it will  be useful, but
# WITHOUT   ANY  WARRANTY;   without  even   the  implied   warranty  of
# MERCHANTABILITY  or FITNESS  FOR A  PARTICULAR PURPOSE.   See  the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
########################################################################

"""Base exceptions for whisperback

"""

class WhisperbackException(Exception):
    """Base class for all exceptions raised by WhisperBack"""
    pass

# Used in whisperback.py

class MisconfigurationException(WhisperbackException):
    """This exception is raised when the configuartion can't be properly
    loaded

    """
    def __init__(self, variable):
        WhisperbackException.__init__(self,
            _("The %s variable was not found in any of the configuration files "
            "/etc/whisperback/config.py, ~/.whisperback/config.py, or ./config.py")
            % variable)

# Used in encryption.py

class EncryptionException (WhisperbackException):
    """This exception is raised when GnuPG fails to encrypt the data"""
    pass
