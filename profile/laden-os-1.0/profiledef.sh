#!/usr/bin/env bash
# shellcheck disable=SC2034
# SPDX-License-Identifier: GPL-3.0-or-later
# Laden OS 1.0.0 Standard edition (based on Arch Linux).
# Structure follows the archiso 92 releng profile (GPL-3.0-or-later).
# Upstream tooling credits (CachyOS and others) live in NOTICE/CREDITS.
iso_name="laden-os"
iso_label="LADEN_100"
iso_publisher="Laden OS <https://laden.no>"
iso_application="Laden OS 1.0.0 Standard live/installer"
iso_version="1.0.0-standard"
install_dir="laden"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# Cap mksquashfs at 8 threads to keep host CPU cooler during release builds.
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '12' '-b' '1M' '-processors' '4')
# tty0 last so it is /dev/console; ttyS0 gives a serial log for VM tests.
kernel_params_x86_64="cow_spacesize=4G console=ttyS0,115200 console=tty0"
file_permissions=(
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/10-laden-live"]="0:0:440"
  ["/etc/polkit-1/rules.d"]="0:0:750"
  ["/usr/lib/laden-live/create-live-user"]="0:0:755"
)
