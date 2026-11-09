#!/usr/bin/env bash
# shellcheck disable=SC2034
# SPDX-License-Identifier: GPL-3.0-or-later
# Profile definition for Laden OS. Structure follows archiso 92 README.profile.rst.
# Boot-loader fragments adapted from the archiso releng profile (GPL-3.0-or-later).

iso_name="laden-os"
iso_label="LADEN_OS"
iso_publisher="Laden OS <https://laden.no>"
iso_application="Laden OS live (based on Arch Linux)"
iso_version="0.1.3-live"
install_dir="laden"
buildmodes=('iso')
bootmodes=(
    'bios.syslinux'
    'uefi.systemd-boot'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# zstd level 6 keeps the lab image practical to build. Level 15 was fine for
# the small desktop and is much slower once the root is tens of gigabytes.
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '6' '-b' '1M')
# Primary console is tty0. ttyS0 is an additional console for VM tests.
kernel_params_x86_64="cow_spacesize=2G console=ttyS0,115200 console=tty0"
file_permissions=(
    ["/etc/sudoers.d/10-laden-live"]="0:0:440"
    ["/usr/lib/laden-os/create-live-user"]="0:0:755"
    ["/usr/lib/laden-os/apply-os-release"]="0:0:755"
    ["/usr/lib/laden-os/generate-identity"]="0:0:755"
    ["/usr/lib/laden-os/report-status"]="0:0:755"
    ["/usr/lib/laden-os/apply-wallpaper"]="0:0:755"
    ["/usr/lib/laden-os/control-port"]="0:0:755"
    ["/usr/lib/laden-os/install-cockpit"]="0:0:755"
    ["/usr/bin/laden-layout"]="0:0:755"
    ["/usr/bin/laden-lab"]="0:0:755"
    ["/usr/bin/lcp-toggle"]="0:0:755"
    ["/usr/bin/laden-install"]="0:0:755"
    ["/usr/lib/laden-os/install-guard"]="0:0:755"
    ["/usr/lib/laden-os/install-finalize"]="0:0:755"
    ["/usr/lib/laden-os/install-system"]="0:0:755"
    ["/usr/bin/calamares"]="0:0:755"
    ["/usr/lib/laden-os/autopsy-jdk"]="0:0:755"
    ["/usr/lib/laden-os/apply-shortcuts"]="0:0:755"
)
