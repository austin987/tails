#! /usr/bin/python3
'''
    Tails upgrade frontend wrapper.

    Test with "python3 electrum.py doctest".
    The tests will start the tor-browser so you probably
    want to use a tester that handles user interaction or
    run the tests from the command line and answer prompts as needed.

    goodcrypto.com converted from bash to python and added basic tests.
'''
import os
import sys
from gettext import gettext

import sh

os.environ['TEXTDOMAIN'] = 'tails'

HOME_DIR = os.environ['HOME']
CONF_DIR = os.path.join(HOME_DIR, '.electrum')

def main():
    """
        >>> # In case you answer Exit
        >>> try:
        ...     main()
        ... except SystemExit:
        ...     pass
    """

    if not electrum_config_is_persistent():
        if not verify_start():
            sys.exit(0)

    run = sh.Command('/usr/bin/electrum')
    run()

def electrum_config_is_persistent():
    """
        Return True iff electrum config is persistent.

        >>> electrum_config_is_persistent()
        False
    """

    filesystem = sh.findmnt('--noheadings',
                                '--output', 'SOURCE',
                                '--target', CONF_DIR).stdout.decode().strip()
    return filesystem in sh.glob('/dev/mapper/TailsData_unlocked[/electrum]')

def verify_start():
    """
        Ask user whether to start Electrum.

        >>> # Assumes you answer Exit
        >>> verify_start()
        False
    """

    disabled_text = gettext('Persistence is disabled for Electrum')
    warning_text = gettext(
        "When you reboot Tails, all of Electrum's data will be lost, including your Bitcoin wallet. It is strongly recommended to only run Electrum when its persistence feature is activated.")
    question_text = gettext('Do you want to start Electrum anyway?')
    dialog_msg = ('<b><big>{}</big></b>\n\n{}\n\n{}\n'.
                  format(disabled_text, warning_text, question_text))
    launch_text = gettext('_Launch')
    exit_text = gettext('_Exit')

    # results 0 == True; 1 == False; 5 == Timeout
    results = sh.zenity('--question', '--title', "", '--default-cancel',
        '--ok-label', '{}'.format(launch_text), '--cancel-label', '{}'.format(exit_text),
        '--text', '{}'.format(dialog_msg), _ok_code=[0,1,5])
    start = results.exit_code == 0

    return start

'''
    >>> # run script
    >>> this_command = sh.Command(sys.argv[0])
    >>> this_command()
    ...
'''
if __name__ == '__main__':
    if sys.argv and len(sys.argv) > 1:
        if sys.argv[1] == 'doctest':
            from doctest import testmod
            testmod()
        else:
            main()
    else:
        main()

    sys.exit(0)

