[[!meta title="Python 3"]]

Now that the missing libraries are in Jessie ([[!tails_ticket 5875]], [[!tails_ticket 6175]]), we need to migrate our custom programs to Python3.

[[!toc levels=2]]

    $ git grep "^ *import " config/
    $ git grep "^ *from [^ -]* import " config/

# Main Git repository

Modules not included in standard library follow:

## ~~config/chroot_local-includes/etc/whisperback/config.py~~

Was migrated to Python3 as part of WhisperBack (see below).

## ~~config/chroot_local-includes/usr/local/bin/lc.py~~

Was migrated to Python3 as part of [[https://labs.riseup.net/code/projects/tails/repository/revisions/2b2b6c76d10db733905fad978340150da3c920a4]] ([[!tails_ticket 10088]])

## ~~config/chroot_local-includes/usr/local/bin/shutdown_helper_applet~~

We will not use this applet in Tails/Jessie, so there is nothing to do.

- `gtk`: deprecated, replaced by `python3-gi` and `gir1.2-gtk-3.0`
- `gnomeapplet`: deprecated, replaced by `python3-gi` and `gir1.2-panelapplet-4.0`

## ~~config/chroot_local-includes/usr/local/bin/tails-about~~

Was migrated to Python3 in Tails 2.6: [[!tails_ticket 10082]]

- `gtk`: deprecated, replaced by `python3-gi` and `gir1.2-gtk-3.0`

## ~~config/chroot_local-includes/usr/local/lib/tails-autotest-remote-shell~~

Ported to Python3.

## ~~config/chroot_local-includes/usr/local/lib/boot-profile~~

Was migrated to Python3 in Tails 2.6: [[!tails_ticket 10083]]

* `pyinotify`: OK, `python3-pyinotify`

## ~~config/chroot_local-includes/usr/local/sbin/tails-additional-software~~

Was migrated to Python3 as part of [[!tails_ticket 15198]] in <https://labs.riseup.net/code/projects/tails/repository/revisions/2abe4abbf69f5c6cde80de6bcc3134734860ca13>: [[!tails_ticket 15067]]

* `posix1e`: OK, `python3-pylibacl`

# ~~Tails Greeter~~

Was migrated to Python3 in Tails 3.0: [[!tails_ticket 5701]]

* `pycountry`: OK, `python3-pycountry`
* `icu`: OK, `python3-icu`

# Tails Installer

Should be migrated to Python3: [[!tails_ticket 10085]]

XXX: this list of dependencies is outdated.

- `configobj`: OK, `python3-configobj`
- `StringIO`: the `StringIO` module is included in the stdlib, and
  available in python3 as `io.StringIO` or `io.BytesIO`
- `PyQt4`: OK, `python3-pyqt4`
- `dbus`: OK, `python3-dbus`
- `parted`: OK, `python3-parted`
- `urlparse`: renamed `urllib.urlparse`

# ~~WhisperBack~~

Ported to Python3.
