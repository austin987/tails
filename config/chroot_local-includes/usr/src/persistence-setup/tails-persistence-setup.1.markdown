% TAILS-PERSISTENCE-SETUP(1) tails-persistence-setup user manual
% This manual page was written by Tails developers <tails@boum.org>
% February 20, 2012

NAME
====

tails-persistence-setup - Tails persistence setup wizard

SYNOPSIS
========

	tails-persistence-setup [OPTIONS]

OPTIONS
=======

`--help`
--------

Print usage information.

`--verbose`
-----------

Get more output.

`--force`
---------

Make some sanity checks non-fatal.

`--override-liveos-mountpoint`
------------------------------

Mountpoint of the Tails system image.

`--override-system-partition`
-----------------------------

The UDI of the partition where Tails is installed, e.g.
`/org/freedesktop/UDisks2/block_devices/sdb1`.

`--step`
--------

Specify once per wizard step to run.

Supported steps are: bootstrap, configure, delete.

Example: `--step bootstrap --step configure`.

`--force-enable-preset`
-----------------------

Specify once per additional preset to forcibly enable.

Example: `--force-enable-preset Thunderbird'`

`--no-display-finished-message`
-------------------------------

Don't display the "Persistence wizard - Finished" message.
