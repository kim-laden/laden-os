#!/bin/bash
# SPDX-License-Identifier: MIT
# Extract a built ISO and scan the squashfs. Does not write a block device.
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 ISO" >&2
    exit 2
fi

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ISO=$(readlink -f "$1")
case "$ISO" in
    /dev/*) echo "refusing /dev path" >&2; exit 2 ;;
esac
if [[ -b $ISO || ! -f $ISO ]]; then
    echo "ISO must be a regular file: $ISO" >&2
    exit 2
fi

UNSQUASHFS=$ROOT/build/host-tools/usr/bin/unsquashfs
if [[ ! -x $UNSQUASHFS ]]; then
    echo "unsquashfs is missing. Run scripts/build-iso.sh once so host tools are extracted." >&2
    exit 2
fi

SCAN=$ROOT/build/scan-root
STAGE=$ROOT/build/scan-stage
if findmnt -R "$SCAN" >/dev/null 2>&1; then
    echo "Refusing to replace $SCAN because something is mounted there." >&2
    exit 2
fi
# The previous extract is owned through subordinate ids. A plain rm cannot
# delete it. Remove it from the same user namespace the unpack used.
if [[ -d $SCAN || -d $STAGE ]]; then
    unshare --map-auto --map-root-user rm -rf -- "$SCAN" "$STAGE"
fi
mkdir -p "$STAGE"

xorriso -osirrox on -indev "$ISO" -extract /laden/x86_64/airootfs.sfs "$STAGE/airootfs.sfs"
"$UNSQUASHFS" -d "$SCAN" -no-xattrs "$STAGE/airootfs.sfs"

# A normal user cannot restore setuid. dbus-daemon-launch-helper then has
# mode 0110 in the extract and cannot be read. Grant user read here only.
# This does not change the ISO.
find "$SCAN" -type f ! -perm -u=r -exec chmod u+r {} +

fail=0
note() {
    echo "$1"
    fail=1
}

scan_log=$ROOT/build/logs/scan-findings.txt
python3 "$ROOT/scripts/scan-secrets.py" "$SCAN" | tee "$scan_log" || true
allow=$ROOT/scripts/scan-allowlist.txt
while IFS= read -r line; do
    case "$line" in
        ''|clean\ *|*' finding(s)') continue ;;
    esac
    rule=${line%% *}
    path=${line#* }
    rel=${path#"$SCAN"/}
    reviewed=0
    while IFS= read -r allowed; do
        case "$allowed" in
            ''|\#*) continue ;;
        esac
        if [[ $rule == "${allowed%% *}" && $rel == "${allowed#* }" ]]; then
            reviewed=1
            echo "reviewed upstream test material: $rule $rel"
            break
        fi
    done <"$allow"
    if (( reviewed == 0 )); then
        note "unexpected scan finding: $rule $rel"
    fi
done <"$scan_log"

machine_id=$(tr -d '[:space:]' <"$SCAN/etc/machine-id" || true)
if [[ $machine_id != uninitialized ]]; then
    note "machine-id is '$machine_id', expected uninitialized"
fi

if [[ -e $SCAN/var/lib/laden-os/service-identity.key ]]; then
    note "service private key is inside the squashfs"
fi

if compgen -G "$SCAN/usr/share/backgrounds/laden/*emerald*" >/dev/null \
    || compgen -G "$SCAN/usr/share/backgrounds/laden/*hp*" >/dev/null; then
    note "rejected wallpaper is inside the squashfs"
fi

(
    cd "$SCAN/usr/share/backgrounds/laden"
    sha256sum -c "$ROOT/branding/SHA256SUMS-wallpapers-v2-ship.txt"
) || fail=1

skel_rc=$SCAN/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc
if ! grep -q 'Image=file:///usr/share/backgrounds/laden/laden-os-lets-do-it-v2-7680x4320.png' "$skel_rc"; then
    note "skel wallpaper is not the v2 8K file"
fi
if grep -q 'laden-os-lets-do-it-7680x4320.png' "$skel_rc"; then
    note "skel still names the v1 wallpaper"
fi
if ! grep -q 'FillMode=2' "$skel_rc"; then
    note "skel wallpaper is missing FillMode=2 (preserve aspect crop)"
fi
if ! grep -q 'b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f' \
    "$SCAN/usr/lib/laden-os/apply-wallpaper"; then
    note "apply-wallpaper does not pin the v2 8K hash"
fi
if [[ -e $SCAN/home/laden ]]; then
    note "home/laden leaked into the image"
fi
if [[ -e $SCAN/etc/sudoers.d/10-laden-dev || -e $SCAN/etc/ssh/sshd_config.d/99-laden-dev.conf ]]; then
    note "development SSH access is inside the image"
fi

if grep -q CacheDir "$SCAN/etc/pacman.conf"; then
    note "live pacman.conf contains CacheDir"
fi

if [[ $(readlink "$SCAN/etc/systemd/system/sshd.service" || true) != /dev/null ]]; then
    note "sshd.service is not masked"
fi

if grep -R -l '/home/laden' "$SCAN/etc" "$SCAN/usr/lib/laden-os" >/dev/null 2>&1; then
    note "host home path is present in etc or laden-os scripts"
fi

if (( fail != 0 )); then
    echo "image scan failed"
    exit 1
fi
echo "image scan passed: $ISO"
