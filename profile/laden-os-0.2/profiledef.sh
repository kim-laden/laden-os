#!/usr/bin/env bash
# shellcheck disable=SC2034
# SPDX-License-Identifier: GPL-3.0-or-later
# Laden OS 0.2.0 Desktop edition (based on CachyOS and Arch Linux).
# Structure follows the archiso 92 releng profile (GPL-3.0-or-later).
iso_name="laden-os"
iso_label="LADEN_020"
iso_publisher="Laden OS <https://laden.no>"
iso_application="Laden OS 0.2.0 Desktop live/installer"
iso_version="0.2.0-desktop"
install_dir="laden"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M' '-processors' '8')
# tty0 last so it is /dev/console; ttyS0 gives a serial log for VM tests.
kernel_params_x86_64="cow_spacesize=4G console=ttyS0,115200 console=tty0"
file_permissions=(
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/10-laden-live"]="0:0:440"
  ["/etc/polkit-1/rules.d"]="0:0:750"
  ["/usr/lib/laden-live/create-live-user"]="0:0:755"
)
