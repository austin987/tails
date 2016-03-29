#! /usr/bin/python
'''
    Get Tails boot info.

    Test with "python tails-get-bootinfo.py doctest".

    Initial conversion from bash by goodcrypto.com

    >>> import os
    >>> import os.path
    >>> import sh
    >>> import sys
    >>> def test_boot(boot):
    ...     """ Run this script. """
    ...
    ...     common_args = ['BOOT_IMAGE=/kernel-boot-path', 'initrd=/initrd-boot-path']
    ...     command_path = os.path.join(os.getcwd(), sys.argv[0])
    ...     this_command = sh.Command(command_path)
    ...     out = this_command(boot, *common_args).stdout.strip()
    ...     print(out)
    >>> test_boot('kernel')
    b'/lib/live/mount/medium/kernel-boot-path'
    >>> test_boot('initrd')
    b'/lib/live/mount/medium/initrd-boot-path'
'''

from __future__ import print_function

import os
import sys

if __name__ == "__main__" and sys.argv[1] == 'doctest':
    import doctest
    doctest.testmod()

LIVE_IMAGE_MOUNTPOINT = '/lib/live/mount/medium'
SCRIPT_NAME = os.path.basename(sys.argv[0])

kernel = initrd = None
for arg in sys.argv:
    if arg.startswith('BOOT_IMAGE='):
        kernel = arg[len('BOOT_IMAGE='):]
    elif arg.startswith('initrd='):
        initrd = arg[len('initrd='):]

# Sanity checks
if not kernel:
    sys.exit(4)
if not initrd:
    sys.exit(5)

if sys.argv[1] == 'kernel':
    print(LIVE_IMAGE_MOUNTPOINT + kernel, end=None)
elif sys.argv[1] == 'initrd':
    print(LIVE_IMAGE_MOUNTPOINT + initrd, end=None)
else:
    print('Usage: {} kernel|initrd PATH'.format(SCRIPT_NAME), file=sys.stderr)
    sys.exit(3)

sys.exit(0)
