#! /usr/bin/python3
'''
    Debug Tails.

    Test with "python3 tails-debugging-info.py doctest" as root.

    goodcrypto.com converted from bash to python and added basic tests.

    *** WARNING about debug_file and debug_directory *********************

    Great attention must be given to the ownership situation of these
    files and their parent directories in order to avoid a symlink-based
    attack that could read the contents of any file and make it
    accessible to the user running this script (typically the live
    user). Therefore, when adding a new file, give as the first argument
    'root' only if the complete path to it (including the file itself)
    is owned by root and already exists before the system is connected to
    the network (that is, before GDM's PostLogin script is run).
    If not, the following rules must be followed strictly:

    * only one non-root user is involved in the ownership situation (the
      file, its dir and the parent dirs). From now on let's assume it is
      the case and call it $USER.

    * if any non-root group has write access, it must not have any
      members.

    If any of these rules does not apply, the file cannot be added here
    safely and something is probably quite wrong and should be
    investigated carefully.
'''
import os
import sys

import sh

os.environ['PATH'] = '/usr/local/bin:/usr/bin:/bin'

def main():
    """
        Print debug information.

        >>> main()
        ...
    """

    debug_file('root', '/proc/cmdline')

    # General hardware and filesystems information
    debug_command(['/usr/sbin/dmidecode', '-s', 'system-manufacturer'])
    debug_command(['/usr/sbin/dmidecode', '-s', 'system-product-name'])
    debug_command(['/usr/sbin/dmidecode', '-s', 'system-version'])
    debug_command(['/usr/bin/lspci'])
    debug_command(['/bin/df', '--human-readable', '--print-type'])
    debug_command(['/bin/mount'])
    debug_command(['/bin/lsmod'])
    debug_file('root', '/proc/asound/cards')
    debug_file('root', '/proc/asound/devices')
    debug_file('root', '/proc/asound/modules')

    # Miscellaneous configuration and log files
    debug_file('root', '/etc/X11/xorg.conf')
    debug_file('Debian-gdm', '/var/log/gdm3/tails-greeter.errors')
    debug_file('root', '/var/log/live/boot.log')
    debug_file('root', '/var/log/live/config.log')
    debug_file('root', '/var/lib/live/config/tails.physical_security')

    # Persistence
    debug_file('root', '/var/lib/gdm3/tails.persistence')
    debug_file('root', '/live/persistence/TailsData_unlocked/persistence.conf')
    debug_file('root', '/live/persistence/TailsData_unlocked/live-additional-software.conf')
    debug_directory('root', '/live/persistence/TailsData_unlocked/apt-sources.list.d')
    debug_file('root', '/var/log/live-persist')

    # The Journal
    debug_command(['/bin/journalctl', '--catalog', '--no-pager'])

def debug_command(args):
    """
        Print the command and then run it.

        >>> args = ['/usr/sbin/dmidecode', '-s', 'system-manufacturer']
        >>> debug_command(args)
        ...
    """
    print()
    print('===== output of command {} ====='.format(' '.join(args)))

    command = args[0]
    run = sh.Command(command)
    if len(args[1:]) > 0:
        response = run(args[1:]).stdout.decode().strip()
    else:
        response = run().stdout.decode().strip()

    print(response)

def debug_file(user, filename):
    """
        Debug if file exists or not.

        >>> debug_file('amnesia', '/etc/hosts')
        ...
    """
    if os.path.exists(filename):
        print()
        print('===== content of {} ====='.format(filename))
        content = sh.sudo('-u', user, 'cat', filename).stdout.decode()
        print(content)

def debug_directory(user, dir_name):
    if not os.path.isdir(dir_name):
        return

    files = os.listdir(dir_name)

    print('===== listing of {} ====='.format(dir_name))
    for f in files:
        print(f)

    for f in files:
        debug_file(user, f)


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
            main()
    else:
        main()

    sys.exit(0)

