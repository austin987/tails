Corresponding ticket: [[!tails_ticket 6064]]

[[!toc levels=2]]

Left to do
==========

Generic
-------

* Minimized applications in the taskbar can't be raised via the
  taskbar. They can be raised via the *Activities Overwiew*.

Toshiba Encore 2 WT8-B
----------------------

* Intel Atom CPU Z3735F @ 1.33GHz (Bay Trail)
* can cold-boot from USB: hold down the Vol+ button, then hold down
  the Power button, until the boot selection menu appears.
  Select the desired boot device and press the Windows key.

### Tails 4.3

* Backlight tuning: GNOME Shell offers the UI, but it has no visible effect.
* Display rotation (probably because we don't install `iio-sensor-proxy`)
* MAC spoofing fails

Works fine
==========

Toshiba Encore 2
----------------

### Tails 4.3

* Boots fine without custom boot loader options.
* Sound
* Wi-Fi
* Battery level monitoring
* touchscreen
* USB

Misc reports
============

* We've been reported that except Wi-Fi, Tails 3.11 works fine
  on the Microsoft Surface Go 10 inch. According to
  [this post](https://www.reddit.com/r/SurfaceLinux/comments/9t53gq/wifi_fixed_on_surface_go_ubuntu_1810/)
  a update of the firmware file (shipped by [[!debpkg firmware-atheros]])
  fixes that.

Resources
=========

* <https://twitter.com/kapper1224> gave an inspiring talk at DebConf18
  ([slides](https://www.slideshare.net/kapper1224/hacking-with-x86-windows-tablet-and-mobile-devices-on-debian-debconf18))
  about "Hacking with x86 Windows Tablet and mobile devices on
  Debian".
* <https://nmilosev.svbtle.com/fedora-on-baytrail-tablets-2017-edition>
* <http://www.studioteabag.com/science/dell-venue-pro-linux/>
