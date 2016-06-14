#! /usr/bin/python3
'''
    Get Tails boot info.

    Test with "python3 tails-get-bootinfo.py doctest".

    goodcrypto.com converted from bash to python and added basic tests.
'''
import os
import sys
import sh

LIVE_IMAGE_MOUNTPOINT = '/lib/live/mount/medium'
SCRIPT_NAME = os.path.basename(sys.argv[0])

def main(args):
    kernel = initrd = None

    result = sh.cat('/proc/cmdline').stdout.decode()
    for line in result.split(' '):
        if line.startswith('BOOT_IMAGE='):
            kernel = line[len('BOOT_IMAGE='):]
        elif line.startswith('initrd='):
            initrd = line[len('initrd='):]

    # Sanity checks
    if not kernel:
        sys.exit(4)
    if not initrd:
        sys.exit(5)

    if args[1] == 'kernel':
        print(LIVE_IMAGE_MOUNTPOINT + kernel, end=None)
    elif args[1] == 'initrd':
        print(LIVE_IMAGE_MOUNTPOINT + initrd, end=None)
    else:
        print('Usage: {} kernel|initrd PATH'.format(SCRIPT_NAME), file=sys.stderr)
        sys.exit(3)

'''
    >>> def test_boot(boot):
    ...     """ Run this script. """
    ...
    ...     common_args = ['BOOT_IMAGE=/kernel-boot-path', 'initrd=/initrd-boot-path']
    ...     command_path = os.path.join(os.getcwd(), sys.argv[0])
    ...     this_command = sh.Command(command_path)
    ...     out = this_command(boot, *common_args).stdout.decode().strip()
    ...     print(out)
    >>> test_boot('kernel')
    b'/lib/live/mount/medium/kernel-boot-path'
    >>> test_boot('initrd')
    b'/lib/live/mount/medium/initrd-boot-path'
'''
if __name__ == "__main__":
    if sys.argv and len(sys.argv) > 1:
        if sys.argv[1] == 'doctest':
            from doctest import testmod
            testmod()
        else:
            main(sys.argv)
        sys.exit(0)
    else:
        print('Usage: tails-get-bootinfo kernel|initrd')
        sys.exit(-1)


