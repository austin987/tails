#!/usr/bin/env bash
# shellcheck disable=SC2034
# AniTails archiso profile definition (compatible with archiso >= 92-1)
# Independent Arch Linux derivative inspired by Tails security architecture.
# NOT an official Tails Project release.

iso_name="anitails"
iso_label="ANITAILS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="AniTails Independent Project (Non-affiliated derivative)"
iso_application="AniTails Amnesic Live System (Arch Linux x86_64)"
iso_version="0.1.0-7.16port"
install_dir="arch"
buildmodes=('iso')
bootmodes=(
  'bios.syslinux'
  'uefi.systemd-boot'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# Tails 7.0+ switched from xz to zstd for faster boot while preserving read-only SquashFS integrity
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')

# IMPORTANT (archiso 92-1 order of operations):
# mkarchiso copies airootfs/ BEFORE pacstrap and immediately applies file_permissions
# via `realpath -q` BEFORE packages are installed — every path listed here MUST exist
# inside archiso/airootfs/ in Git. Post-pacstrap package directories (like /var/lib/tor)
# are enforced by zz-99-anitails-finalize.hook (`anitails-alpm-finalize`).
file_permissions=(
  ["/etc/shadow"]="0:0:0400"
  ["/etc/gshadow"]="0:0:0400"
  ["/etc/nftables.conf"]="0:0:0600"
  ["/etc/resolv.conf"]="0:0:0644"
  ["/etc/tor/torrc"]="0:43:0640"
  ["/etc/sudoers.d"]="0:0:0750"
  ["/etc/sudoers.d/00-anitails-hardening"]="0:0:0440"
  ["/etc/polkit-1"]="0:0:0755"
  ["/etc/polkit-1/rules.d"]="0:0:0750"
  ["/etc/polkit-1/rules.d/10-anitails-deny-internal-disks.rules"]="0:0:0644"
  ["/etc/NetworkManager/dispatcher.d/00-firewall.sh"]="0:0:0755"
  ["/etc/NetworkManager/dispatcher.d/10-tor.sh"]="0:0:0755"
  ["/usr/local/bin/anitails-clock-setup"]="0:0:0755"
  ["/usr/local/bin/anitails-cuda-check"]="0:0:0755"
  ["/usr/local/bin/anitails-gpu-detect"]="0:0:0755"
  ["/usr/local/bin/anitails-gpu-select"]="0:0:0755"
  ["/usr/local/bin/anitails-persistence"]="0:0:0755"
  ["/usr/local/bin/anitails-sandbox-app"]="0:0:0755"
  ["/usr/local/bin/anitails-tor-browser"]="0:0:0755"
  ["/usr/local/bin/anitails-tor-connect"]="0:0:0755"
  ["/usr/local/bin/anitails-verify-truststore"]="0:0:0755"
  ["/usr/local/lib/anitails-alpm-finalize"]="0:0:0755"
  ["/usr/local/lib/anitails-create-netns"]="0:0:0755"
  ["/usr/local/lib/anitails-initramfs-restore"]="0:0:0755"
  ["/usr/local/lib/anitails-onion-grater"]="0:0:0755"
  ["/usr/local/lib/anitails-shutdown-ram-wipe"]="0:0:0755"
  ["/usr/local/lib/anitails-spoof-mac"]="0:0:0755"
  ["/usr/local/lib/anitails-swapon-disabled"]="0:0:0755"
  ["/usr/local/lib/anitails-udev-watchdog-wrapper"]="0:0:0755"
  ["/usr/local/lib/anitails-unblock-network"]="0:0:0755"
  ["/home/amnesia"]="1000:1000:0700"
)
