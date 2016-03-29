#! /usr/bin/python
'''
    Tails upgrade frontend wrapper.

    Conversion from bash to python by goodcrypto.com

    >>> # run script
    >>> import sh
    >>> import sys
    >>> this_command = sh.Command(sys.argv[0])
    >>> this_command()
    ...
'''

from __future__ import print_function

import os
import sys
from gettext import gettext

import sh

os.environ['TEXTDOMAIN'] = 'tails'

CONF_DIR = '{}/.electrum'.format(os.environ['HOME'])

def electrum_config_is_persistent():
    """
        Return True iff electrum config is persistent.

        >>> electrum_config_is_persistent()
        False
    """

    filesystem = str(sh.findmnt('--noheadings',
                                '--output', 'SOURCE',
                                '--target', CONF_DIR).stdout).strip()
    return filesystem in sh.glob('/dev/mapper/TailsData_unlocked[/electrum]')

def verify_start():
    """
        Ask user whether to start Electrum.

        >>> verify_start()
        False
    """

    disabled_text = gettext('Persistence is disabled for Electrum')
    warning_text = gettext(
        "When you reboot Tails, all of Electrum's data will be lost, including your Bitcoin wallet. It is strongly recommended to only run Electrum when its persistence feature is activated.")
    question_text = gettext('Do you want to start Electrum anyway?')
    launch_text = gettext('_Launch')
    exit_text = gettext('_Exit')
    dialog_msg = ('<b><big>{}</big></b>\n\n{}\n\n{}\n'.
                  format(disabled_text, warning_text, question_text))

    # Since zenity can't set the default button to cancel, we switch the
    # labels and interpret the return value as its negation.
    try:
        sh_results = sh.zenity('--question',
                               '--title', '',
                               '--ok-label', exit_text,
                               '--cancel-label', launch_text,
                               '--text', dialog_msg,
                               _ok_code=[0, 1])
        start = sh_results.exit_code == 1
    except sh.ErrorReturnCode:
        start = False
    else:
        start = True

    return start

if not electrum_config_is_persistent():
    if not verify_start():
        sys.exit(0)

usr_bin_electrum = sh.Command('/usr/bin/electrum')
usr_bin_electrum(*sys.argv[1:])

