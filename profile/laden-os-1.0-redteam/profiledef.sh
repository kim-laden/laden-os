#!/usr/bin/env bash
# shellcheck disable=SC2034
# SPDX-License-Identifier: GPL-3.0-or-later
# Laden OS 1.0.1 Red Team live USB (based on Arch Linux).
iso_name="laden-os"
iso_label="LADEN_101_RT"
iso_publisher="Laden OS <https://laden.no>"
iso_application="Laden OS 1.0.1 Red Team live/installer"
iso_version="1.0.1-redteam"
install_dir="laden"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '12' '-b' '1M' '-processors' '4')
kernel_params_x86_64="cow_spacesize=4G console=ttyS0,115200 console=tty0"
file_permissions=(
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/10-laden-live"]="0:0:440"
  ["/etc/polkit-1/rules.d"]="0:0:750"
  ["/usr/lib/laden-live/create-live-user"]="0:0:755"
)
