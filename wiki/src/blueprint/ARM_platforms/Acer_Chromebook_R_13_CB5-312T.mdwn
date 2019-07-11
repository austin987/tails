[[!meta title="Debian on Acer Chromebook R 13 CB5-312T"]]

[[!toc levels=2]]

# Models

This was initially tested on CB5-312T K7SP, and further work was done
with a CB5-312T K2L7.

# Resources

* <https://wiki.debian.org/InstallingDebianOn/Acer/Chromebook%2013%20CB5-312T/stretch>
* <http://forums.debian.net/viewtopic.php?t=103468>
* <https://wiki.debian.org/InstallingDebianOn/Asus/C201>
* <https://wiki.debian.org/InstallingDebianOn/Acer/Chromebook_13_CB5-311-T8BT>
* <https://wiki.debian.org/InstallingDebianOn/Samsung/ARMChromebook>
* <https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices/custom-firmware>
* <https://archlinuxarm.org/platforms/armv8/mediatek/acer-chromebook-r13>
* Interesting Debian packages: `vboot-utils vboot-kernel-utils u-boot-tools`

# Current status

**Update**: see [[Kernel approach 4: Arch Linux' ChromeOS-based kernel|Acer_Chromebook_R_13_CB5-312T#arch-chromeos-based-kernel]] for the most
promising status update so far.

Both with the Chrome OS kernel and the Debian kernel approaches I end
up with something that fails in the exact same way: at the developer
mode start screen I press Ctrl+U, and then the display shuts down but
the computer remains running indefinitely. So it seems that an attempt
at booting actually happens; if the signing is messed up, or the
partitions don't look right, I should just get an error beep when
pressing Ctrl+U. -- anonym

Also, with the ChromeOS kernel, when booting from a USB stick that
blinks on access, there's quite some blinking after booting, then
a ~20 seconds break (with `rootdelay=20`), then lots more blinking (if
I install gdm3), and then a little bit more here and then. But blindly
typing `root\n$ROOT_PASSWORD\npoweroff\n` doesn't turn the machine
off, and pressing TAB (for shell completion) doesn't trigger more
blinking. So it looks like the system might actually have started, but
provides no VT. Interestingly,
<https://wiki.debian.org/InstallingDebianOn/Asus/C201> says: "If you
are running a newer ChromeOS, CONFIG_VT may be disabled in the kernel.
this prevents the creation of consoles and the starting of Xorg from
current stable. You need to install a tool that uses the framebuffer
directly to interact with your new operating system. A patch is
available and tested, but has yet to make it to the point of being
submittable to the Xorg development team. See:
<http://demo1.faikvm.com/trac/wiki/C201>". Might this explain why the
ChromeOS kernel doesn't display anything, even if it has
`DRM_MEDIATEK` enabled? See below an attempt at booting a modified
ChromeOS kernel with `CONFIG_VT` enabled.
-- intrigeri

Wrt. the Debian kernel, the black screen might be fixed by enabling the
`DRM_MEDIATEK` Kconfig option, that's not enabled in Debian currently:

* <https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=2e726dc4b4e2dd3ae3fe675f9d3af88a2d593ee1>
* <https://lists.freedesktop.org/archives/dri-devel/2016-May/108049.html>

See "Kernel approach 5: custom Debian kernel" below for a try at it.

# On a Debian machine

<div class="note">This Debian machine does not have to be ARM.</div>

Set some variables:

	MNT=/mnt/debian
	sudo mkdir -p ${MNT}
	DEBIAN_CODENAME=stretch

If using a 8 GiB USB drive:

	DEV=$(readlink -f /dev/disk/by-id/usb-XXX)
	KERNEL_PART=${DEV}1
	ROOT_PART=${DEV}2
	DATA_PART_SIZE=15292383

Else, if using a 64 GiB micro-SD card:

	DEV=$(readlink -f /dev/disk/by-id/mmc-XXX)
	KERNEL_PART=${DEV}p1
	ROOT_PART=${DEV}p2
	DATA_PART_SIZE=XXX

Partitioning the device:

	sudo parted --script ${DEV} mklabel gpt
	sudo cgpt create ${DEV}

XXX: the kernel partition is (still) too small for a Stretch kernel +
the gzip-compressed initrd generated from a running Debian desktop
system. Compressing it with xz (as instructed below) fixes that, but it
would be nice to be a bit more generous during the partitioning stage :)

	sudo cgpt add -i 1 -S 1 -T 5 -P 12 -t kernel -l kernel -b 8192 -s 262144 ${DEV}
	sudo cgpt add -t data -l / -b 270336 -s ${DATA_PART_SIZE} ${DEV}
	sudo blockdev --rereadpt ${DEV}
	sudo mkfs.ext4 ${ROOT_PART}
	sudo mount ${ROOT_PART} ${MNT}
	sudo debootstrap --arch=arm64 --foreign "${DEBIAN_CODENAME:?}" \
	        "${MNT:?}" \
	        http://ftp.de.debian.org/debian

Unmount the root filesystem:

	sudo umount ${MNT}

# On the Chromebook

Enable developer mode.

At the ChromeOS Greeter screen, configure a Wi-Fi connection.

Enter a shell with `CTRL + ALT + Next` (the `Next` key is F2, on the
top row of the keyboard).

Enable booting a self-signed kernel from USB/micro-SD:

	enable_dev_usb_boot

Set some variables (adjust as above if using a micro-SD card):

	DEV=/dev/sda
	ROOT_PART=${DEV}2
	KERNEL_PART=${DEV}1
	MNT=/media/debian
	mkdir -p ${MNT}

If using a USB stick, unmount from wherever ChromeOS decided to
auto-mount the device (apparently micro-SD are not auto-mounted):

	umount ${ROOT_PART}

In any case, mount the Debian root filesystem where we want it:

	mount ${ROOT_PART} ${MNT}

Complete the bootstrap:

	chroot ${MNT} /debootstrap/debootstrap --second-stage

Configure the system and install what you'll need to make Wi-Fi
and hardware work once you reboot on Debian:

	cat > ${MNT}/etc/fstab <<EOF
	${ROOT_PART} / ext4 errors=remount-ro 0 1
	EOF
	echo "chromian" > ${MNT}/etc/hostname
	cp /etc/resolv.conf ${MNT}/etc/resolv.conf
	chroot ${MNT} apt-get update
	chroot ${MNT} apt-get install -y \
	                 alsa-utils \
	                 cgpt \
	                 network-manager \
	                 vboot-utils \
	                 vboot-kernel-utils \
	                 wireless-tools
	chroot ${MNT} passwd -d root


## Kernel approach 1 - try the Chrome OS kernel

Guess which kernel partition is the latest.  Run cgpt show and see
which one (KERN-A or KERN-B) has the highest priority.

	cgpt show /dev/mmcblk0

Copy the ChromeOS kernel to the root filesystem,
In this example we'll assume it was KERN-B:

	dd if=/dev/mmcblk0p4 of=${MNT}/boot/chromeos.kernel.signed

Declare the kernel flags:

	cat > ${MNT}/boot/kernel.flags <<EOF
	console=tty1 printk.time=1 nosplash rootwait root=${ROOT_PART} ro rootfstype=ext4 lsm.module_locking=0 debug
	EOF

Sign the kernel:

	cat > ${MNT}/boot/sign-kernel.sh <<EOF
	vbutil_kernel --repack /boot/vmlinuz.signed --keyblock \
	  /usr/share/vboot/devkeys/kernel.keyblock --version 1 \
	  --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
	  --config /boot/kernel.flags --oldblob /boot/chromeos.kernel.signed \
	  --arch arm
	EOF
	chroot ${MNT} sh /boot/sign-kernel.sh

XXX: the resulting `vmlinuz.signed` is 5.9M large, while
`chromeos.kernel.signed` was 16M. Might it be that the ChromeOS one
embeds some kernel modules we need?

Write the signed kernel to the kernel partition:

	dd bs=1M if=${MNT}/boot/vmlinuz.signed of=${KERNEL_PART}

Copy the ChromeOS kernel modules into the root filesystem:

	mkdir -p ${MNT}/lib/modules
	cp -r /lib/modules/* ${MNT}/lib/modules

Copy the non-free firmware for the wifi device:

	mkdir -p ${MNT}/lib/firmware/
	cp -r /lib/firmware/* ${MNT}/lib/firmware
	mkdir -p ${MNT}/opt/google/
	cp -a /opt/google/touch ${MNT}/opt/google/

Umount the filesystems:

	umount ${MNT}

### Debugging

I (intrigeri) have also tried:

	console=tty0 printk.time=1 nosplash rootwait root=/dev/mmcblk1p2 ro rootfstype=ext4 lsm.module_locking=0 debug
	console=tty0 console=tty1 printk.time=1 nosplash rootwait root=/dev/mmcblk1p2 rw rootfstype=ext4 lsm.module_locking=0 debug
	printk.time=1 nosplash rootwait root=/dev/mmcblk1p2 ro rootfstype=ext4 lsm.module_locking=0 debug
	loglevel=7 init=/sbin/init oops=panic panic=-1 noinitrd vt.global_cursor_default=0 printk.time=1 nosplash rootwait root=/dev/mmcblk1p2 ro rootfstype=ext4 lsm.module_locking=0 debug
	console=tty1 printk.time=1 nosplash rootdelay=20 root=/dev/mmcblk1p2 rw rootfstype=ext4 lsm.module_locking=0 debug

I've also tried:

 * installing more stuff inside the rootfs:
   `tasksel install standard && apt install console-setup`

And finally these two ones did something different, i.e. the screen
stays black and desperately empty, but this time its backlight is
turned on:

	console=tty1 printk.time=1 nosplash rootwait root=/dev/mmcblk0p2 ro rootfstype=ext4 lsm.module_locking=0 debug
	console=tty0 printk.time=1 nosplash rootwait root=/dev/mmcblk0p2 ro rootfstype=ext4 lsm.module_locking=0 debug

> anonym speaking: FWIW, I cannot reproduce (backlight remains off).

Now, `/dev/mmcblk0` is really the internal flash storage, and not my
micro-SD, as pointing `root=` to the ChromeOS root partition like this
does start ChromeOS:

	console=tty1 printk.time=1 nosplash rootwait root=/dev/mmcblk0p5 ro rootfstype=ext4 lsm.module_locking=0 debug

> anonym speaking: FWIW, I cannot reproduce this (nothing boots).

So to sum up, FWIW the "backlight turns on" behavior happens when…
`root=` is pointed to a ChromeOS kernel partition (that's definitely
not ext4). So, at least this kernel _is_ able to turn on backlight,
and for some reason it apparently does not until it has found its root
partition (even if it fails to mount it).

Note that even after dropping `rootwait` and `rootdelay=`, the
backlight doesn't turn on.

Conclusion: the official ChromeOS kernel lacks too much stuff that
a Debian userspace needs.

> anonym speaking: I'm less sure about this conclusion; the Arch linux
> one that works for us *is* a ChromeOS Kernel, with 13 patches
> applied, none which looks relevant for boot issues (except
> `0008-Downgrade-mmc1-speed.patch`, but it targets the .dtb file and
> I tried rebuilding it with the patch => no joy).
>
> TODO: retry with all the patches applied?

## Kernel approach 2 - Debian's kernel

XXX: retry with a more recent Debian kernel.

From inside ChromeOS:

	chroot "${MNT:?}" apt install initramfs-tools
	chroot "${MNT:?}" sed -i'' 's,^COMPRESS=.*,COMPRESS=xz,' \
	   /etc/initramfs-tools/initramfs.conf
	chroot "${MNT:?}" apt install linux-image-4.*-arm64-unsigned

Note that we're using the `-unsigned` kernel, in case the Secure Boot
signature on the signed one causes problems with the ChromeOS firmware.

Then go back to a Debian system, and:

	sudo mount ${ROOT_PART} ${MNT}

We need some `mt8173-*.dtb` compiled device tree descriptors, but
they are not present in Debian's kernel because `CONFIG_ARCH_MEDIATEK`
is not enabled. So to start with, we use the ones shipped in Arch Linux
2017-04 rootfs for "oak" platforms. (Note: Ubuntu
[includes](http://ports.ubuntu.com/ubuntu-ports/pool/main/l/linux/linux-image-4.10.0-19-generic_4.10.0-19.21_arm64.deb)
`mt8173-evb.dtb` (evb = "evaluation board"), but that's not enough for
the system we're testing on.)

Put them in `${MNT}/boot/dtbs.archlinux/mediatek/`.

Then prepare the FIT (`.itb`) image:

	sudo tee "${MNT:?}/boot/vmlinuz-Debian.its" <<EOF
	/dts-v1/;
	/ {
	    description = "Debian kernel image with one or more FDT blobs";
	    images {
	        kernel@1{
	            description = "kernel";
	            data = /incbin/("vmlinuz-4.9.0-2-arm64");
	            type = "kernel_noload";
	            arch = "arm64";
	            os = "linux";
	            compression = "none";
	            load = <0>;
	            entry = <0>;
	        };
	        fdt@1{
	            description = "mt8173-elm-rev0.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-elm-rev0.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@2{
	            description = "mt8173-elm-rev1.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-elm-rev1.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@3{
	            description = "mt8173-elm-rev3.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-elm-rev3.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@4{
	            description = "mt8173-hana-rev0.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-hana-rev0.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@5{
	            description = "mt8173-oak-rev2.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev2.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@6{
	            description = "mt8173-oak-rev3.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev3.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@7{
	            description = "mt8173-oak-rev4.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev4.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@8{
	            description = "mt8173-oak-rev5.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev5.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@9{
	            description = "mt8173-oak-rev6.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev6.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        ramdisk@1{
	            description = "initrd.img";
	            data = /incbin/("initrd.img-4.9.0-2-arm64");
	            type = "ramdisk";
	            arch = "arm64";
	            os = "linux";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	    };
	    configurations {
	        default = "conf@1";
	        conf@1{
	            kernel = "kernel@1";
	            fdt = "fdt@1";
	            ramdisk = "ramdisk@1";
	        };
	        conf@2{
	            kernel = "kernel@1";
	            fdt = "fdt@2";
	            ramdisk = "ramdisk@1";
	        };
	        conf@3{
	            kernel = "kernel@1";
	            fdt = "fdt@3";
	            ramdisk = "ramdisk@1";
	        };
	        conf@4{
	            kernel = "kernel@1";
	            fdt = "fdt@4";
	            ramdisk = "ramdisk@1";
	        };
	        conf@5{
	            kernel = "kernel@1";
	            fdt = "fdt@5";
	            ramdisk = "ramdisk@1";
	        };
	        conf@6{
	            kernel = "kernel@1";
	            fdt = "fdt@6";
	            ramdisk = "ramdisk@1";
	        };
	        conf@7{
	            kernel = "kernel@1";
	            fdt = "fdt@7";
	            ramdisk = "ramdisk@1";
	        };
	        conf@8{
	            kernel = "kernel@1";
	            fdt = "fdt@8";
	            ramdisk = "ramdisk@1";
	        };
	        conf@9{
	            kernel = "kernel@1";
	            fdt = "fdt@9";
	            ramdisk = "ramdisk@1";
	        };
	    };
	};
	EOF
	sudo mkimage -D "-I dts -O dtb -p 2048" \
	      -f "${MNT:?}/boot/vmlinuz-Debian.its" \
	      "${MNT:?}/boot/vmlinuz-Debian.itb" && \
	echo "console=tty1 init=/sbin/init root=PARTUUID=%U/PARTNROFF=1 rootwait rw nosplash" \
	   > cmdline.Debian && \
	dd if=/dev/zero of=bootloader.bin bs=512 count=1 && \
	sudo vbutil_kernel --pack "${MNT:?}/boot/vmlinuz-Debian.signed" \
	      --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
	      --version 1 \
	      --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
	      --config cmdline.Debian \
	      --bootloader bootloader.bin \
	      --vmlinuz "${MNT:?}/boot/vmlinuz-Debian.itb" \
	      --arch aarch64

**Just for the record**, here's a supposed alternative to above
`vbutil_kernel` command but it seems to work worse (Ctrl+U at the
Chrome OS developer mode boot screen behaves just as if it's not a
valid device to boot from):

	futility --debug vbutil_kernel \
	    --arch arm \
	    --version 1 \
	    --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
	    --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
	    --bootloader cmdline \
	    --config cmdline \
	    --vmlinuz kernel-initrd.itb \
	    --pack vmlinuz.signed \

Install the FIT image:

	sudo dd bs=1M if="${MNT:?}/boot/vmlinuz-Debian.signed" \
	   of="${KERNEL_PART:?}" && \
	sync
	sudo umount "${MNT:?}"

Mark the newly written kernel partition as good and set the
priority:

	cgpt add -i 1 -S 1 -T 5 -P 12 ${DEV}

The resulting USB stick blinks endlessly after pressing CTRL+U,
and the backlight remains off.

## Kernel approach 3 - custom Chrome OS kernel

> anonym speaking: I tried these steps from the `chromeos-4.14` branch
> with no success.

I've also tried building a custom ChromeOS kernel with added drivers
we might need. Instructions below are based on
<http://wiki.baserock.org/guides/baserock-native-cb5-311/>
and Arch Linux'
[`.its` file, `mkimage` and `vbutil_kernel` command lines](https://github.com/archlinuxarm/PKGBUILDs/blob/master/core/linux-oak/PKGBUILD#L118):

	sudo apt install gcc-5-aarch64-linux-gnu
	git checkout -b chromeos-3.18 chromium/chromeos-3.18
	./chromeos/scripts/prepareconfig chromiumos-mediatek && \
	   ./scripts/config -e CONFIG_FRAMEBUFFER_CONSOLE && \
	   ./scripts/config -m CONFIG_USB_NET_CDC_MBIM && \
	   ./scripts/config -m CONFIG_VLAN_8021Q && \
	   ./scripts/config -e CONFIG_VT && \
	   ./scripts/config -e CONFIG_VT_CONSOLE && \
	   ./scripts/config -d CONFIG_ERROR_ON_WARNING && \
	   ./scripts/config -d CONFIG_MAC80211_DEBUGFS && \
	   make \
	      ARCH=arm64 CC=aarch64-linux-gnu-gcc-5 \
	      CROSS_COMPILE=aarch64-linux-gnu- \
	      oldnoconfig WIFIVERSION=-4.2 && \
	   make -j$(ncpus) \
	      ARCH=arm64 CC=aarch64-linux-gnu-gcc-5 \
	      CROSS_COMPILE=aarch64-linux-gnu- \
	      -k Image modules dtbs WIFIVERSION=-4.2 && \
	   sudo make \
	      ARCH=arm64 CC=aarch64-linux-gnu-gcc-5 \
	      CROSS_COMPILE=aarch64-linux-gnu- \
	      INSTALL_PATH="${MNT:?}/boot" \
	      INSTALL_MOD_PATH="${MNT:?}" \
	      firmware_install modules_install dtbs_install WIFIVERSION=-4.2 && \
	   wget -O ./kernel-archlinux.its \
	      https://github.com/archlinuxarm/PKGBUILDs/raw/master/core/linux-oak/kernel.its && \
	   mkimage -D "-I dts -O dtb -p 2048" \
	      -f kernel-archlinux.its kernel-chromeos-custom.itb && \
	   wget -O ./cmdline-archlinux \
	      https://github.com/archlinuxarm/PKGBUILDs/raw/master/core/linux-oak/cmdline && \
	   dd if=/dev/zero of=bootloader.bin bs=512 count=1 && \
	   vbutil_kernel \
	          --pack kernel-chromeos-custom.signed \
	          --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
	          --version 1 \
	          --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
	          --config ./cmdline-archlinux \
	          --bootloader ./bootloader.bin \
	          --vmlinuz kernel-chromeos-custom.itb \
	          --arch aarch64 && \
	   sudo dd bs=1M if=kernel-chromeos-custom.signed of="${KERNEL_PART:?}" && \
	   sync

As a result Debian Stretch starts, which validates this `.its` file and
this way of generating the FIT (`.itb`) image. But GDM fails to start
and Wi-Fi is not working. Copying the additional firmware shipped in
Arch Linux 2017-04 rootfs for "oak" platforms (see below), without
replacing existing ones, yields a different startup error (for some
reason, the system tries to start X.Org instead of Wayland, and fails).
Whatever: if we're ready to build a kernel based on the ChromeOS one,
we'd better start from the Arch Linux kernel config + included firmware
(see below).

<a id="arch-chromeos-based-kernel"></a>

## Kernel approach 4: Arch Linux' ChromeOS-based kernel

The results below are about `ArchLinuxARM-2017.09-oak-rootfs.tar.gz`,
that's available at the time of writing in
<http://os.archlinuxarm.org/os/mediatek/>.

> anonym speaking: I have reproduced this with:
> `ArchLinuxARM-2017.11-oak-rootfs.tar.gz` yay!

I've followed
<https://archlinuxarm.org/platforms/armv8/mediatek/acer-chromebook-r13>
to install Arch Linux on a USB stick, and it booted flawlessly.
BTW, it says the board is a Mediatek Elm rev3.

So this seems to be the best starting point for us currently.

So, let's try booting Debian with the Arch Linux kernel, kernel
modules and firmware. The following instructions assumes that
the partitioning and debootstrap steps have been done already.

	ARCH_LINUX_ROOTFS=/path/to/the/extracted/rootfs

	sudo mount "${ROOT_PART:?}" "${MNT:?}"
	sudo rsync -av "${ARCH_LINUX_ROOTFS:?}"/boot/ \
	        "${MNT:?}"/boot/
	sudo rsync -av "${ARCH_LINUX_ROOTFS:?}"/lib/firmware/ \
	        "${MNT:?}"/lib/firmware/
	sudo rsync -av "${ARCH_LINUX_ROOTFS:?}"/lib/modules/ \
	        "${MNT:?}"/lib/modules/
	sudo find "${MNT:?}"/lib/modules/ -name *.ko.gz \
	          -exec gunzip '{}' \;
	sudo dd bs=1M if="${MNT:?}/boot/vmlinux.kpart" of="${KERNEL_PART:?}"
	sync
	sudo depmod --basedir "${MNT:?}" 3.18.0-9-ARCH
	sudo umount "${MNT:?}"

### Status

 * Debian Stretch boots fine and starts GDM (if installed).
 * I can log into a GNOME on Wayland session.
 * The "Search" key (that replaces Caps Lock) is mapped to Super, i.e.
   it opens the Overview in GNOME Shell.
 * Touchpad: tap-to-click (once enabled) and two-finger scrolling work.
 * Wi-Fi works.
 * Display backlight brightness can be adjusted with the GNOME Shell
   UI (in the top-right menu).
 * Sound works after unmuting a bunch of channels with `alsamixer` as
   documented on the *Wiki* tab of
   <https://archlinuxarm.org/platforms/armv8/mediatek/acer-chromebook-r13>
 * The GNOME UI doesn't notice when AC power is disconnected.
 * Accelerometer and automatic screen rotation: kind of works, but not
   in a smooth/reliable way enough to be useful.
 * Keyboard is automatically disabled when the screen is flipped to
   tablet mode.
 * Touchscreen: basically works, but I didn't try to exercise it much.
   It seems that some parts of the GNOME UI don't work with touch but
   _only_ when the display is rotated (e.g. flipped to tablet mode).
   Some tweaks are needed to make it work really well, e.g.
   `MOZ_USE_XINPUT2=1` for touch scrolling in Firefox 55.0.3-1
    and setting `browser.gesture.pinch.in` to `cmd_fullZoomReduce` +
    `browser.gesture.pinch.out` to `cmd_fullZoomEnlarge` for pinch
    to zoom.
 * Video playback:
   - GNOME Shell does not get any hardware acceleration (glamor, dri3,
     EGL) so it's "falling back to sw". And then both with Wayland and
     X.Org, full-screen video playback eats tons of CPU to the point it
     is totally unusable with Totem and VLC, and pretty bad even with
     mpv. That's probably due to the lack of a `mediatek_dri.so` DRI
     module for Mesa or VA-API support (the latter because
     [[!debpts gstreamer1.0-vaapi]] is not installable on sid today);
     I'll retry when the latter is fixed, that might help.
   - GNOME Flashback (Metacity): even though the window manager does
     not use tons of CPU, the end-result is only perceptibly better
     with mpv (and even there it's not perfect). Touchscreen support
     is far behind the GNOME Shell experience (no gesture to interact
     with the desktop, poorly integrated screen keyboard, no automatic
     rotation of the display).

## Kernel approach 5: custom Debian kernel

> anonym speaking: I last tried linux-image-4.13.0-1-arm64

Here we
[rebuild](https://kernel-handbook.alioth.debian.org/ch-common-tasks.html#s-common-building)
the Debian kernel with the `CONFIG_ARCH_MEDIATEK` and
`CONFIG_DRM_MEDIATEK` Kconfig options enabled; and while we're at it, we
get some more inspiration from the
[kernel that allowed us to boot Debian on this machine](https://github.com/archlinuxarm/PKGBUILDs/blob/master/core/linux-oak/config).

This assumes that the dtbs are already in
`${MNT}/boot/dtbs.archlinux/mediatek/`.

On a Debian arm64 system:

	apt install linux-source libssl-dev
	cd /usr/src
	tar xaf linux-source-*.tar.xz
	cd linux-source-*
	cp /boot/config-* .config
	make oldconfig
	scripts/config --disable EFI_STUB
	scripts/config --disable DEBUG_INFO
	scripts/config --enable  ARCH_MEDIATEK
	scripts/config --enable  DRM_MEDIATEK
	scripts/config --enable  DRM_MEDIATEK_HDMI
	scripts/config --enable  VIDEO_MEDIATEK_VPU
	scripts/config --enable  VIDEO_MEDIATEK_MDP
	scripts/config --enable  VIDEO_MEDIATEK_VCODEC
	scripts/config --enable  VIDEO_MEDIATEK_JPEG
	scripts/config --enable  SND_SOC_MEDIATEK
	scripts/config --module  SND_SOC_MT8173
	scripts/config --module  SND_SOC_MT8173_MAX98090
	scripts/config --module  SND_SOC_MT8173_RT5650
	scripts/config --module  SND_SOC_MT8173_RT5650_RT5514
	scripts/config --module  SND_SOC_MT8173_RT5650_RT5676
	scripts/config --enable  ARM_MT8173_CPUFREQ
	scripts/config --enable  NET_VENDOR_MEDIATEK
	scripts/config --enable  I2C_MT65XX
	scripts/config --enable  SPI_MT65XX
	scripts/config --enable  PINCTRL_MT8173
	scripts/config --module  MEDIATEK_MT6577_AUXADC
	scripts/config --module  MTK_THERMAL
	scripts/config --module  MEDIATEK_WATCHDOG
	scripts/config --disable SERIAL_8250_MT6577
	scripts/config --disable SND_SOC_MT2701
	scripts/config --enable  USB
	scripts/config --enable  USB_XHCI_HCD
	scripts/config --enable  USB_XHCI_MTK
	scripts/config --enable  PHY_MT65XX_USB3
	scripts/config --enable  COMMON_CLK_MT8125
	scripts/config --enable  COMMON_CLK_MT8173
	scripts/config --enable  MTK_IOMMU
	scripts/config --enable  MTK_PMIC_WRAP
	scripts/config --enable  MTK_SCPSYS
	scripts/config --module  PWM_MTK_DISP
	scripts/config --module  MTK_EFUSE
	scripts/config --disable MODULE_SIG_ALL
	scripts/config --disable MODULE_SIG_KEY and
	scripts/config --disable SYSTEM_TRUSTED_KEYS
	make oldconfig
	make deb-pkg
	dpkg -i ../linux-image-*.deb

On a Debian system (tested on my amd64 sid one):

	sudo tee "${MNT:?}/boot/vmlinuz-Debian-custom.its" <<EOF
	/dts-v1/;
	/ {
	    description = "Custom Debian kernel image with one or more FDT blobs";
	    images {
	        kernel@1{
	            description = "kernel";
	            data = /incbin/("vmlinuz-4.9.18");
	            type = "kernel_noload";
	            arch = "arm64";
	            os = "linux";
	            compression = "gzip";
	        };
	        fdt@1{
	            description = "mt8173-elm-rev0.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-elm-rev0.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@2{
	            description = "mt8173-elm-rev1.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-elm-rev1.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@3{
	            description = "mt8173-elm-rev3.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-elm-rev3.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@4{
	            description = "mt8173-hana-rev0.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-hana-rev0.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@5{
	            description = "mt8173-oak-rev2.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev2.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@6{
	            description = "mt8173-oak-rev3.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev3.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@7{
	            description = "mt8173-oak-rev4.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev4.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@8{
	            description = "mt8173-oak-rev5.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev5.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@9{
	            description = "mt8173-oak-rev6.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev6.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        ramdisk@1{
	            description = "initrd.img";
	            data = /incbin/("initrd.img-4.9.18");
	            type = "ramdisk";
	            arch = "arm64";
	            os = "linux";
	            compression = "lzma";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	    };
	    configurations {
	        default = "conf@1";
	        conf@1{
	            kernel = "kernel@1";
	            fdt = "fdt@1";
	            ramdisk = "ramdisk@1";
	        };
	        conf@2{
	            kernel = "kernel@1";
	            fdt = "fdt@2";
	            ramdisk = "ramdisk@1";
	        };
	        conf@3{
	            kernel = "kernel@1";
	            fdt = "fdt@3";
	            ramdisk = "ramdisk@1";
	        };
	        conf@4{
	            kernel = "kernel@1";
	            fdt = "fdt@4";
	            ramdisk = "ramdisk@1";
	        };
	        conf@5{
	            kernel = "kernel@1";
	            fdt = "fdt@5";
	            ramdisk = "ramdisk@1";
	        };
	        conf@6{
	            kernel = "kernel@1";
	            fdt = "fdt@6";
	            ramdisk = "ramdisk@1";
	        };
	        conf@7{
	            kernel = "kernel@1";
	            fdt = "fdt@7";
	            ramdisk = "ramdisk@1";
	        };
	        conf@8{
	            kernel = "kernel@1";
	            fdt = "fdt@8";
	            ramdisk = "ramdisk@1";
	        };
	        conf@9{
	            kernel = "kernel@1";
	            fdt = "fdt@9";
	            ramdisk = "ramdisk@1";
	        };
	    };
	};
	EOF
	sudo mkimage -D "-I dts -O dtb -p 2048" \
	      -f "${MNT:?}/boot/vmlinuz-Debian-custom.its" \
	      "${MNT:?}/boot/vmlinuz-Debian-custom.itb" && \
	echo "console=tty1 init=/sbin/init root=PARTUUID=%U/PARTNROFF=1 rootwait rw nosplash" \
	   > cmdline.Debian-custom && \
	dd if=/dev/zero of=bootloader.bin bs=512 count=1 && \
	sudo vbutil_kernel --pack "${MNT:?}/boot/vmlinuz-Debian-custom.signed" \
	      --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
	      --version 1 \
	      --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
	      --config cmdline.Debian-custom \
	      --bootloader bootloader.bin \
	      --vmlinuz "${MNT:?}/boot/vmlinuz-Debian-custom.itb" \
	      --arch aarch64 && \
	sudo dd bs=1M if="${MNT:?}/boot/vmlinuz-Debian-custom.signed" \
	   of="${KERNEL_PART:?}" && \
	sync
	sudo umount "${MNT:?}"

The resulting USB stick blinks endlessly after pressing CTRL+U, and the
backlight remains off.

I've also tried compressing the initrd with lzma, and used
`compression = "lzma"` in the `ramdisk@1` section accordingly:
same result.

I *think* there's something wrong either in the vmlinuz/initrd format,
or in the way we embed them in the FIT image.

### Next things to try

 * `type = "kernel"` instead of `type = "kernel_noload"`?
 * various values for the load address and entry point?

## Kernel approach 6: Arch Linux' aarch64 generic kernel

Arch Linux ARMv8 AArch64 Multi-platform rootfs tarball
(<https://archlinuxarm.org/platforms/armv8/generic>), that ships with
a mainline kernel
([config](https://github.com/archlinuxarm/PKGBUILDs/tree/master/core/linux-aarch64)):
it'll probably tell us what's the hardware support level we can possibly
get with a Debian kernel (assuming all the needed build options are
enabled) currently.

The following instructions assumes that the partitioning and debootstrap
steps have been done already.

	ARCH_LINUX_ROOTFS=/path/to/the/extracted/rootfs

	sudo mount "${ROOT_PART:?}" "${MNT:?}"
	sudo rsync -av "${ARCH_LINUX_ROOTFS:?}"/boot/ \
	        "${MNT:?}"/boot/
	sudo rsync -av "${ARCH_LINUX_ROOTFS:?}"/lib/firmware/ \
	        "${MNT:?}"/lib/firmware/
	sudo rsync -av "${ARCH_LINUX_ROOTFS:?}"/lib/modules/ \
	        "${MNT:?}"/lib/modules/
	sudo find "${MNT:?}"/lib/modules/ -name *.ko.gz \
	          -exec gunzip '{}' \;
	sudo depmod --basedir "${MNT:?}" 4.10.8-1-ARCH

	sudo tee "${MNT:?}/boot/vmlinuz-Arch-generic.its" <<EOF
	/dts-v1/;
	/ {
	    description = "Custom Debian kernel image with one or more FDT blobs";
	    images {
	        kernel@1{
	            description = "kernel";
	            data = /incbin/("Image");
	            type = "kernel_noload";
	            arch = "arm64";
	            os = "linux";
	            compression = "none";
	        };
	        fdt@1{
	            description = "mt8173-elm-rev0.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-elm-rev0.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@2{
	            description = "mt8173-elm-rev1.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-elm-rev1.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@3{
	            description = "mt8173-elm-rev3.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-elm-rev3.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@4{
	            description = "mt8173-hana-rev0.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-hana-rev0.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@5{
	            description = "mt8173-oak-rev2.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev2.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@6{
	            description = "mt8173-oak-rev3.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev3.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@7{
	            description = "mt8173-oak-rev4.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev4.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@8{
	            description = "mt8173-oak-rev5.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev5.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        fdt@9{
	            description = "mt8173-oak-rev6.dtb";
	            data = /incbin/("dtbs.archlinux/mediatek/mt8173-oak-rev6.dtb");
	            type = "flat_dt";
	            arch = "arm64";
	            compression = "none";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	        ramdisk@1{
	            description = "initrd.img";
	            data = /incbin/("initramfs-linux.img");
	            type = "ramdisk";
	            arch = "arm64";
	            os = "linux";
	            compression = "gzip";
	            hash@1{
	                algo = "sha1";
	            };
	        };
	    };
	    configurations {
	        default = "conf@1";
	        conf@1{
	            kernel = "kernel@1";
	            fdt = "fdt@1";
	            ramdisk = "ramdisk@1";
	        };
	        conf@2{
	            kernel = "kernel@1";
	            fdt = "fdt@2";
	            ramdisk = "ramdisk@1";
	        };
	        conf@3{
	            kernel = "kernel@1";
	            fdt = "fdt@3";
	            ramdisk = "ramdisk@1";
	        };
	        conf@4{
	            kernel = "kernel@1";
	            fdt = "fdt@4";
	            ramdisk = "ramdisk@1";
	        };
	        conf@5{
	            kernel = "kernel@1";
	            fdt = "fdt@5";
	            ramdisk = "ramdisk@1";
	        };
	        conf@6{
	            kernel = "kernel@1";
	            fdt = "fdt@6";
	            ramdisk = "ramdisk@1";
	        };
	        conf@7{
	            kernel = "kernel@1";
	            fdt = "fdt@7";
	            ramdisk = "ramdisk@1";
	        };
	        conf@8{
	            kernel = "kernel@1";
	            fdt = "fdt@8";
	            ramdisk = "ramdisk@1";
	        };
	        conf@9{
	            kernel = "kernel@1";
	            fdt = "fdt@9";
	            ramdisk = "ramdisk@1";
	        };
	    };
	};
	EOF
	sudo mkimage -D "-I dts -O dtb -p 2048" \
	      -f "${MNT:?}/boot/vmlinuz-Arch-generic.its" \
	      "${MNT:?}/boot/vmlinuz-Arch-generic.itb" && \
	echo "console=tty1 init=/sbin/init root=PARTUUID=%U/PARTNROFF=1 rootwait rw nosplash" \
	   > cmdline.Arch-generic && \
	dd if=/dev/zero of=bootloader.bin bs=512 count=1 && \
	sudo vbutil_kernel --pack "${MNT:?}/boot/vmlinuz-Arch-generic.signed" \
	      --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
	      --version 1 \
	      --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
	      --config cmdline.Arch-generic \
	      --bootloader bootloader.bin \
	      --vmlinuz "${MNT:?}/boot/vmlinuz-Arch-generic.itb" \
	      --arch aarch64 && \
	sudo dd bs=1M if="${MNT:?}/boot/vmlinuz-Arch-generic.signed" \
	   of="${KERNEL_PART:?}" && \
	sync
	sudo umount "${MNT:?}"

Same result as with the Debian kernels, which tends to confirm there's
something wrong either in the vmlinuz/initrd format, or in the way we
embed them in the FIT image.

XXX: when running `mkimage`, try dropping `-p 2048`, adding `-A
arm64`, using `-f auto` (with `-A`, `-O`, `-T` and `-C`).

Another idea would be to have the Chromebook's bootloader
[load our own GRUB](https://wiki.linaro.org/LEG/Engineering/Kernel/GRUBonUBOOT),
that will itself be able to deal with whatever we give it (without
having to mess with FIT and `mkimage`), *but* apparently GRUB for arm64
only supports EFI (confirmed by [[!debpkg grub-uboot]]).
