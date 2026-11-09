#!/bin/bash
# SPDX-License-Identifier: MIT
# Build Calamares 3.4.2 inside a Laden OS system. Arch does not ship it.
# Refuses to run on the workstation: /etc/laden-os/product.conf is the marker.
set -euo pipefail

if [[ ! -f /etc/laden-os/product.conf ]]; then
    echo "Run this inside Laden OS. It does not install Calamares on the workstation." >&2
    exit 2
fi
if ! command -v patch >/dev/null; then
    echo "The patch package is required to apply the disk guard." >&2
    exit 2
fi

expected=733bbbb00dc9f84874bd5c22960952f317ea2537565431179fa2152b2fbfdccc
work=/var/tmp/laden-calamares
mkdir -p "$work"
cd "$work"
if [[ ! -f calamares-3.4.2.tar.gz ]]; then
    curl -fL --retry 3 -o calamares-3.4.2.tar.gz \
        https://codeberg.org/Calamares/calamares/releases/download/v3.4.2/calamares-3.4.2.tar.gz
fi
echo "$expected  calamares-3.4.2.tar.gz" | sha256sum -c -
rm -rf src build
mkdir src
tar -xzf calamares-3.4.2.tar.gz -C src --strip-components=1
patch -p1 -d src < /usr/share/laden-os/installer/calamares-protect-disks.patch
cmake -S src -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DINSTALL_CONFIG=OFF \
    -DINSTALL_POLKIT=OFF \
    -DBUILD_TESTING=OFF \
    -DWITH_QT6=ON \
    -DSKIP_MODULES="dracut;dracutlukscfg;dummycpp;dummyprocess;dummypython;finishedq;initramfs;initramfscfg;interactiveterminal;keyboardq;localeq;notesqml;openrcdmcryptcfg;packagechooser;packagechooserq;plasmalnf;plymouthcfg;services-openrc;summaryq;tracking;usersq;welcomeq;zfs;zfshostid;initcpio;initcpiocfg;mkinitfs;grubcfg;rawfs;unpackfsc;netinstall;packages;oemid;license;fsresizer;contextualprocess;luksbootkeyfile;luksopenswaphookcfg;hostinfo"
cmake --build build
cmake --install build
rm -f /usr/share/applications/calamares.desktop
echo "calamares installed"
