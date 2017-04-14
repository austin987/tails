This is about [[!tails_ticket 10972]].

[[!toc levels=3]]

Related pages
=============

[[!map pages="blueprint/ARM_platforms/*"]]

Pros & cons
===========

## Pros

* It is likely that cheap laptops are going to be more and more often
  based on ARM. So, supporting ARM would have several advantages:
  - People who can't afford a more expensive computer might more
    easily afford a ARM-based one ⇒ supporting Tails on ARM would make
    it more accessible economically speaking.
  - It could allow more people to dedicate a machine to Tails, which
    can have a number of advantages, such as: one can choose a machine
    that they can carry with them all the time (⇒ physical security of
    the hardware); one avoids the risk of their (adversary -owned)
    non-Tails operating system corrupting the firmware in a way that
    can in turn compromise Tails.

* Most mobile touch devices, e.g. tablets, are based on ARM
  these days ([[!tails_ticket 6064]]).

* Some concerns about (Intel) x86 technologies, like the Intel ME,
  might be less of a problem for the time being on ARM. This is no
  magic wand, though: as Joanna Rutkowska writes in her
  [State considered harmful](http://blog.invisiblethings.org/2015/12/23/state_harmful.html)
  paper, "there is nothing special in ARM-based architecture that
  could prevent a vendor from introducing backdoors into the SoCs they
  produce".

## Cons

* A huge amount of work is needed to make this happen, since it
  impacts basically all kinds of teams and skills: user support,
  release process and workload, infrastructure, quality assurance,
  Installation Assistant + DAVE, etc.

* This has the potential to spread our energy a bit too thinly, e.g.
  in terms of maintenance workload, or in terms of acquiring
  maintaining and knowledge and skills.

* There are lots of unknowns: boot loaders, drivers and hardware
  support. It's an entirely new world for most of us ⇒ in the current
  state of things, it is hard to estimate the resources we would need
  to make it happen.

* Tor Browser [[!tor_bug 12631 desc="is not supported on ARM yet"]].

## Other remarks

* It might be a good thing, for the Tails project, to have a big thing
  to do together, that at least one people from each team would need
  to be somewhat involved in.

* The Tor project may be interested in supporting ARM platforms better
  (e.g. for Tor Browser). This could be a good opportunity to (learn
  how to) work together more tightly, be it on the technical or
  fundraising / paperwork side.

Hardware
========

## Lists of devices

Useful, up-to-date lists of devices can be found there:

* [Developer Information for Chrome OS Devices](https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices/)
* [Arch Linux ARM platform comparison](https://archlinuxarm.org/platforms/)
* [Arch Linux ARM downloads](https://archlinuxarm.org/about/downloads)

## CPU architecture

Current (mid-2014 to early 2016) ARM Chromebooks have one of:

* Nvidia's [[!wikipedia Tegra]] K1 T124 (32-bit), that has
  [[!wikipedia ARM Cortex-A15]], that is ARMv7-A architecture; it has
  VFPv4

* [[!wikipedia ARM Cortex-A17]] (e.g.
  in [[!wikipedia Rockchip_RK3288]] (32-bit), that is ARMv7-A
  architecture; it has VFPv4

For Jessie,
<https://www.debian.org/releases/stable/armhf/ch02s01.html.en> reads:

* Debian/armhf works only on newer 32-bit ARM processors which
  implement at least the ARMv7 architecture with version 3 of the ARM
  vector floating point specification (VFPv3). It makes use of the
  extended features and performance enhancements available on
  these models.

* Debian/arm64 works on 64-bit ARM processors which implement at least
  the ARMv8 architecture.

⇒ armhf should support all current ARM Chromebooks.

Also, 64-bit ARM CPUs can apparently run code that was compiled
for armhf.

⇒ armhf should support all ARM Chromebooks for the foreseeable future.

**Update** one year later — April 2017, some ARMv8 (64-bit) ones have
appeared:

* [[!wikipedia MediaTek]] MT8173 ([[!wikipedia PowerVR]] GX6250 GPU),
  e.g. in the Acer Chromebook R13 and Lenovo N23 Yoga Chromebook
* [Rockchip_RK3399](https://en.wikipedia.org/wiki/Rockchip#RK33xx_series)
  ([[!wikipedia Mali (GPU)]] T860 MP4 GPU), e.g. in the Samsung
  Chromebook Plus

On the 32-bit front, a few RK3288-based tablets and media boxes keep
appearing, but the latest 32-bit ARM Chromebook was released in
2015-11.

## Drivers

### Debian

Let's see how current (early 2016) Debian supports ARM Chromebooks.

* Acer Chromebook 13 (CB5-311), Tegra K1
  - [[!debwiki InstallingDebianOn/Acer/Chromebook_13_CB5-311-T8BT]]
    suggests it may require a custom kernel
* Asus Chromebook C201, Rockchip RK3288
  - [[!debwiki InstallingDebianOn/Asus/C201]]
    suggests it may require a custom kernel
* Asus Chromebook Flip, Rockchip RK3288
* HP Chromebook 14 (some models), Tegra K1

XXX: update this section with newer information, e.g. after
we've managed to boot a Debian kernel on an
[[Acer Chromebook R 13|ARM_platforms/Acer_Chromebook_R_13_CB5-312T]].

### How others handle it

Kali provides one image per supported system
([list of images](https://www.offensive-security.com/kali-linux-arm-images/),
[documentation](http://docs.kali.org/category/kali-on-arm)).
Their
[build scripts](https://github.com/offensive-security/kali-arm-build-scripts)
display lots of machine-specific variations, e.g. kernel version,
additional drivers and firmware, X.Org and ALSA configuration.

Arch Linux provides
[one image](https://archlinuxarm.org/about/downloads) per
[supported board](https://archlinuxarm.org/wiki/Platforms), and indeed
their installation instructions point to a different rootfs tarball,
each with a different kernel, e.g. the peach (ChromeOS 3.8 armv7h
kernel), veyron (ChromeOS 3.14 armv7h kernel), oak (ChromeOS 3.18
aarch64 kernel) ones. But they also have more generic images, e.g.
ARMv7 Multi-platform, ARMv7 Chromebook, and ARMv8 AArch64
Multi-platform ones, that ship with the mainline kernel and a bunch of
dtb files. It's not clear how doable it would be to create an image
that works well on devices that have different boards: including all
the needed dtb files seems easy, but is there a single (e.g. ChromeOS)
kernel version that has all the needed drivers and firmware?

The [Arch Linux ARM PKGBUILDs repository](https://github.com/archlinuxarm/PKGBUILDs)
have all their ARM-specific changes. In particular:

* <https://github.com/archlinuxarm/PKGBUILDs/tree/master/alarm>
  has ARM-specific packages, mostly firmware, drivers and bootloaders
* <https://github.com/archlinuxarm/PKGBUILDs/tree/master/core/>
  has the build information for various kernels (including `.its`
  files, `mkimage` and `vbutil_kernel` command lines)

Bootloader
==========

## Chromebooks

On Chromebooks, one can "flash" a custom bootloader in the place where
the kernel would usually be found by the embedded bootloader.
This allows booting an OS in a more "traditional" way than what the
included bootloader requires, and brings a number of advantages, such
as: ability to edit the kernel command line, booting from external
storage without pressing CTRL+U (if that bootloader is installed on
the internal storage), bootloader menu (think "Troubleshooting Mode").

More information:

* <https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices/custom-firmware>
* <https://www.chromium.org/chromium-os/firmware-porting-guide/using-nv-u-boot-on-the-samsung-arm-chromebook>

## Coreboot

Sadly, the "legacy boot" mode that makes it "easy" to boot another OS
than ChromeOS, thanks to the
[SeaBIOS](http://www.coreboot.org/SeaBIOS) payload of coreboot, is not
available on ARM.

XXX: is Coreboot or U-Boot installed on ARM Chromebooks?
<https://www.coreboot.org/Chromebooks> lists only X86 devices.
