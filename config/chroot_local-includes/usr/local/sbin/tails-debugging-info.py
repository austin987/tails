#! /usr/bin/python3
'''
    Debug Tails.

    Test with "python3 tails-debugging-info.py doctest" as root.

    goodcrypto.com converted from bash to python and added basic tests.
'''
import os
import sys

import sh

os.environ['PATH'] = '/usr/local/bin:/usr/bin:/bin'

def main():
    """
        Debug Tails.

        >>> main()
        ...
    """

    debug_command(['/usr/sbin/dmidecode', '-s', 'system-manufacturer'])
    debug_command(['/usr/sbin/dmidecode', '-s', 'system-product-name'])
    debug_command(['/usr/sbin/dmidecode', '-s', 'system-version'])
    debug_command(['/bin/lsmod'])
    debug_command(['/bin/mount'])
    debug_command(['/usr/bin/lspci'])
    debug_command(['/bin/journalctl', '--catalog', '--no-pager'])

    """
        Great attention must be given to the ownership situation of these
        files and their parent directories in order to avoid a symlink-based
        attack that could read the contents of any file and make it
        accessible to the user running this script (typicall the live
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
    """
    debug_file('root', '/etc/X11/xorg.conf')
    debug_file('root', '/proc/asound/cards')
    debug_file('root', '/proc/asound/devices')
    debug_file('root', '/proc/asound/modules')
    debug_file('Debian-gdm', '/var/log/gdm3/tails-greeter.errors')
    debug_file('root', '/var/log/live-persist')
    debug_file('root', '/var/log/live/boot.log')
    debug_file('root', '/var/log/live/config.log')
    debug_file('root', '/var/lib/gdm3/tails.persistence')
    debug_file('root', '/var/lib/live/config/tails.physical_security')
    debug_file('root', '/live/persistence/TailsData_unlocked/persistence.conf')
    debug_file('root', '/live/persistence/TailsData_unlocked/live-additional-software.conf')

def debug_command(args):
    """
        Print the command and then run it.

        >>> args = ['/usr/sbin/dmidecode', '-s', 'system-manufacturer']
        >>> debug_command(args)
        ...
    """
    print(file=sys.stderr)
    print('===== output of command {} ====='.format(' '.join(args)), file=sys.stderr)

    command = args[0]
    run = sh.Command(command)
    if len(args[1:]) > 0:
        response = run(args[1:]).stdout.decode().strip()
    else:
        response = run().stdout.decode().strip()

    print(response, file=sys.stderr)

def debug_file(user, filename):
    """
        Debug if file exists or not.

        >>> debug_file('amnesia', '/etc/hosts')
        ...
    """
    if os.path.exists(filename):
        print(file=sys.stderr)
        print('===== content of {} ====='.format(filename), file=sys.stderr)
        content = sh.sudo('-u', user, 'cat', filename).stdout.decode()
        print(content, file=sys.stderr)


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

