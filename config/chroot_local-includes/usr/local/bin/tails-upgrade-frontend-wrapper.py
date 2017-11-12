#! /usr/bin/python3
'''
    Tails upgrade frontend wrapper.

    Test with "python3 tails-upgrade-frontend-wrapper.py doctest".
    The tests will start the upgrade process which could pop up a dialog box
    so you probably want to use a tester that handles user interaction or
    run the tests from the command line and answer prompts as needed.

    goodcrypto.com converted from bash to python and added basic tests.
'''
import os
import sys
import time
from gettext import gettext

import sh

os.environ['PATH'] = '/usr/local/bin:/usr/bin:/bin'
os.environ['TEXTDOMAIN'] = 'tails'

CMD = os.path.basename(sys.argv[0])
TORDATE_DIR = '/var/run/tordate'
TORDATE_DONE_FILE = '{}/done'.format(TORDATE_DIR)
INOTIFY_TIMEOUT = 60
MIN_REAL_MEMFREE = (300 * 1024)
RUN_AS_USER = 'tails-upgrade-frontend'

def main(*args):
    """
        Tails upgrade frontend wrapper.

        >>> try:
        ...     main()
        ...     fail()
        ... except SystemExit:
        ...     pass
    """

    time.sleep(30)

    check_free_memory(MIN_REAL_MEMFREE)

    # Go to a place where everyone, especially Archive::Tar::Wrapper called by
    # tails-install-iuk, can chdir back after it has chdir'd elsewhere to do
    # its job.
    os.chdir('/')

    sh.xhost('+SI:localuser:{}'.format(RUN_AS_USER))

    # try forever
    done = False
    while not done:
        try:
            if len(args) > 0:
                result = sh.sudo('-u', RUN_AS_USER, '/usr/bin/tails-upgrade-frontend', sh.glob(args))
            else:
                result = sh.sudo('-u', RUN_AS_USER, '/usr/bin/tails-upgrade-frontend')
        except sh.ErrorReturnCode:
            pass
        else:
            done = True

    sh.xhost('-SI:localuser:{}'.format(RUN_AS_USER))
    sys.exit(result.exit_code)

def error(msg):
    """
        Show error and exit.

        >>> try:
        ...     error('testing')
        ...     fail()
        ... except SystemExit:
        ...     pass
    """

    cli_text = '{}: {} {}'.format(CMD, gettext('error:'), msg)
    dialog_text = '''<b><big>{}</big></b>\n\n{}'''.format(gettext('Error'), msg)
    print(cli_text, file=sys.stderr)

    sh.zenity('--error', '--title', "", '--text', '{}'.format(dialog_text), _ok_code=[0,1,5])
    sys.exit(1)

def check_free_memory(min_real_memfree):
    """
        Check for enough free memory.

        >>> check_free_memory(MIN_REAL_MEMFREE)
    """

    for line in open('/proc/meminfo'):
        if line.startswith('MemFree:'):
            fields = line.split()
            memfree = int(fields[1])
        elif line.startswith('Buffers:'):
            fields = line.split()
            buffers = int(fields[1])
        elif line.startswith('Cached:'):
            fields = line.split()
            cached = int(fields[1])
    df_text = sh.df('--type=tmpfs', '--local', '--output=used', '--total').stdout.decode()
    tmpfs = int(df_text.strip().split('\n')[-1])
    real_memfree = (memfree + buffers + cached) - tmpfs

    errormsg = gettext('''\"<b>Not enough memory available to check for upgrades.</b>

Make sure this system satisfies the requirements for running Tails.
See file:///usr/share/doc/tails/website/doc/about/requirements.en.html

Try to restart Tails to check for upgrades again.

Or do a manual upgrade.
See https://tails.boum.org/doc/first_steps/upgrade#manual\"''')

    if real_memfree < min_real_memfree:
        print('Only {} MemFree + '.format(real_memfree), end=None)
        print('Buffers + Cached - usage of tmpfs, ', end=None)
        print('while {} is needed.'.format(MIN_REAL_MEMFREE), file=sys.stderr)
        error(errormsg)

'''
    >>> # run script
    >>> this_command = sh.Command(sys.argv[0])
    >>> this_command()
    <BLANKLINE>
'''
if __name__ == '__main__':
    if sys.argv and len(sys.argv) > 1:
        if sys.argv[1] == 'doctest':
            from doctest import testmod
            testmod()
        else:
            main(sys.argv[1:])
    else:
        main()

    sys.exit(0)

