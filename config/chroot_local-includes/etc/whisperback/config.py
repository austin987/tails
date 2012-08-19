# -*- coding: UTF-8 -*-
#
# Tails configuration file for Whisperback
# ==========================================
#
# This is a python script that will be read at startup. Any python
# syntax is valid.

########################################################################
# WhisperBack - Send a feedback in an encrypted mail
# Copyright (C) 2009-2010 Amnesia <amnesia@boum.org>
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
# IMPORTS
# Do not change this - required to parse path
import os.path

# Custom imports
import subprocess
import random
import locale
import gettext

# DOCUMENTATION

def __get_localised_doc_link():
    """Return the link to the localised documentation

    @returns  the link to the localised documentation if available, or to the
            english version
    """

    # Try to get the list of supported languages codes supported by the
    # documentation according to the $TAILS_WIKI_SUPPORTED_LANGUAGES
    # environnement variable. If unset, fallback to `en`
    try:
        wiki_supported_languages = os.environ["TAILS_WIKI_SUPPORTED_LANGUAGES"].split(' ')
    except KeyError:
        wiki_supported_languages = ['en']

    # locale.getlocale returns a tuple (language code, encoding)
    # the language is the two first character of the RFC 1766 "language code"
    system_language_code = locale.getdefaultlocale()[0]
    if system_language_code:
        system_language = system_language_code[0:2]
    else:
        system_language = None

    # Get the language code of the localised documentation if available, or
    # fallback to `en`
    if system_language in wiki_supported_languages:
        localised_doc_language = system_language
    else:
        localised_doc_language = 'en'

    return ("file:///usr/share/doc/tails/website/doc/first_steps/bug_reporting." +
        localised_doc_language +
        ".html")

def _(string):
    try:
        string = gettext.translation("amnesia", "/usr/share/locale").lgettext(string)
    except IOError:
        pass
    finally:
        return string

# The right panel help (HTML string)
html_help = _(
"""<h1>Help us fix your bug!</h1>
<p>Read <a href="%s">our bug reporting instructions</a>.</p>
<p><strong>Do not include more personal information than
needed!</strong></p>
<h2>About giving us an email address</h2>
<p>If you don't mind disclosing some bits of your identity
to Tails developers, you can provide an email address to
let us ask more details about the bug. Additionally entering
a public PGP key enables us to encrypt such future
communication.</p>
<p>Anyone who can see this reply will probably infer you are
a Tails user. Time to wonder how much you trust your
Internet and mailbox providers?</p>
""") % __get_localised_doc_link()

# ENCRYPTION
#
# This section defines encryption parameters

# The path to the OpenPGP keyring to use. If None, use OpenPGP default
# keyring.
gnupg_keyring = "/usr/share/keyrings/tails-keyring.gpg"

# RECIPIENT
#
# This section defines the recepient parameters

# The address of the recipient
to_address = "tails@boum.org"

# The fingerprint of the recipient's GPG key 
to_fingerprint = "09F6BC8FEEC9D8EE005DBAA41D2975EDF93E735F"

# SENDER
#
# This section defines the sender parameters

# The address of the sender
from_address = "devnull@tails.boum.org"

# SMTP
#
# This section defines the SMTP server parameters
#
# The SMTP server to use to send the mail
smtp_host = "4mvq3pnvid3awjln.onion"
# The port to connect to on that SMTP server
smtp_port = 25
# The path to a file containing the certificate to trust
# This can be either a CA certificate used to sign the SMTP server
# certificate or the certificate of the SMTP server itself
smtp_tlscafile = os.path.join("/", "etc", "whisperback", "4mvq3pnvid3awjln.onion.pem")

# MESSAGE
#
# This section defines the message parameters

# The subject of the email to be sent
# Please take into account that this will not be encrypted
mail_subject = "Bug report: %x" % random.randrange(16**32)

# A callback function to get information to prepend to the mail
# (this information will be encrypted). This is useful to add
# software version.
# 
# It should not take any parameter, and should return a string to be
# preprended to the email
def mail_prepended_info():
    """Returns the version of the running amnesia system
    
    @return The output of tails-version, if any, or an english string 
            explaining the error
    """
  
    try:
      amnesia_version_process = subprocess.Popen ("tails-version", 
                                                 stdout=subprocess.PIPE)
      amnesia_version_process.wait()
      amnesia_version = amnesia_version_process.stdout.read()
    except OSError:
      amnesia_version = "tails-version command not found"
    except subprocess.CalledProcessError:
      amnesia_version = "tails-version returned an error"
    
    return "Tails-Version: %s\n" % amnesia_version

# A callback function to get information to append to the email
# (this information will be encrypted). This is useful to add
# configuration files usebul for debugging.
# 
# It should not take any parameter, and should return a string to be
# appended to the email
def mail_appended_info():
    """Returns debugging informations on the running amnesia system
    
    @return XXX: document me
    """

    debug_files = ["/etc/X11/xorg.conf", "/var/log/Xorg.0.log",
                   "/var/log/live-persist", "/var/lib/gdm3/tails.persistence"]
    debug_commands = ["/bin/dmesg", "/bin/lsmod", "/usr/bin/lspci"]

    debugging_info = ""

    for debug_command in debug_commands:
        debugging_info += "\n===== output of command %s =====\n" % debug_command
        try:
            process = subprocess.Popen (debug_command, 
                                        stdout=subprocess.PIPE)
            for line in process.stdout:
                debugging_info += line
            process.wait()
        except OSError:
            debugging_info += "%s command not found\n" % debug_command
        except subprocess.CalledProcessError:
            debugging_info += "%s returned an error\n" % debug_command

    for debug_file in debug_files:
        debugging_info += "===== content of %s =====\n" % debug_file
        f = None
        try:
            f = open(debug_file)
            debugging_info += f.read()
        except IOError:
            debugging_info += "%s not found\n" % debug_file
        finally:
            if f is not None: f.close()

    return debugging_info
