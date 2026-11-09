#!/bin/bash
# SPDX-License-Identifier: MIT
# Build the Laden OS live ISO with upstream archiso.
# Does not install packages onto the host, write block devices, or use sudo.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PHASE=1
if [[ $# -gt 0 ]]; then
    PHASE=$1
fi
if [[ "$PHASE" != 1 ]]; then
    echo "Only phase 1 is buildable until BIOS and UEFI boot evidence exists. Got: $PHASE" >&2
    exit 2
fi

CACHE=$ROOT/build/cache
TOOLS=$ROOT/build/host-tools
# release-iso.sh points these at a fresh directory so a release does not
# reuse the development work tree or overwrite an ISO that is already named.
WORK=${LADEN_WORK:-$ROOT/build/work}
OUT=${LADEN_OUT:-$ROOT/build/out}
PROFILE=$ROOT/build/profile-phase1
LOGDIR=$ROOT/build/logs
mkdir -p "$CACHE" "$TOOLS" "$OUT" "$LOGDIR"
echo $$ >"$LOGDIR/build-phase1.pid"
: >"$LOGDIR/build-phase1.log"
echo "phase1-start $(date -Is)" >>"$LOGDIR/build-phase1.log"

refuse_path() {
    local path=$1
    case "$path" in
        /dev|/*/dev/*) echo "refusing path under /dev: $path" >&2; exit 2 ;;
    esac
    if [[ -b $path || -c $path ]]; then
        echo "refusing block or character device: $path" >&2
        exit 2
    fi
}
refuse_path "$WORK"
refuse_path "$OUT"
refuse_path "$PROFILE"

available_kb=$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')
if (( available_kb < 40 * 1024 * 1024 )); then
    echo "Need at least 40 GiB free on $ROOT. Have ${available_kb} KiB." >&2
    exit 2
fi

if ! unshare --map-auto --map-root-user true; then
    echo "User namespaces are not available. A rootless archiso build cannot start." >&2
    exit 2
fi

download() {
    local file=$1 url=$2
    if [[ ! -f $CACHE/$file ]]; then
        curl -fL --retry 3 -o "$CACHE/$file" "$url"
    fi
    tar -C "$TOOLS" -I zstd -xf "$CACHE/$file"
}

download archiso-92-1-any.pkg.tar.zst \
    https://geo.mirror.pkgbuild.com/extra/os/x86_64/archiso-92-1-any.pkg.tar.zst
download arch-install-scripts-32-1-any.pkg.tar.zst \
    https://geo.mirror.pkgbuild.com/extra/os/x86_64/arch-install-scripts-32-1-any.pkg.tar.zst
download squashfs-tools-4.7.5-1-x86_64.pkg.tar.zst \
    https://geo.mirror.pkgbuild.com/extra/os/x86_64/squashfs-tools-4.7.5-1-x86_64.pkg.tar.zst

export PATH="$TOOLS/usr/bin:$PATH"
command -v mkarchiso >/dev/null
command -v pacstrap >/dev/null
command -v mksquashfs >/dev/null

python3 "$ROOT/scripts/scan-secrets.py" "$ROOT/profile/laden-os"
python3 -m unittest discover -s "$ROOT/tests" -v

sumfile=$ROOT/branding/SHA256SUMS-wallpapers-v2-ship.txt
(
    cd "$ROOT/branding"
    sha256sum -c "$sumfile"
)

if findmnt -R "$WORK" >/dev/null 2>&1; then
    echo "Refusing to replace $WORK because something is mounted there." >&2
    findmnt -R "$WORK" >&2 || true
    exit 2
fi
# The previous rootless build owns some files through subordinate ids.
# Remove them from the same user namespace. A plain rm cannot.
if [[ -d $WORK ]]; then
    unshare --map-auto --map-root-user rm -rf -- "$WORK"
fi
rm -rf "$PROFILE"
mkdir -p "$WORK" "$(dirname "$PROFILE")"
cp -a "$ROOT/profile/laden-os" "$PROFILE"
# The lab file is the reviewed toolkit. mkarchiso only reads packages.x86_64.
if [[ -f $PROFILE/packages.d/lab.txt ]]; then
    {
        echo ""
        echo "# Included from packages.d/lab.txt"
        grep -E '^[^#[:space:]]' "$PROFILE/packages.d/lab.txt"
    } >>"$PROFILE/packages.x86_64"
fi
if [[ -f $PROFILE/packages.d/installer.txt ]]; then
    {
        echo ""
        echo "# Included from packages.d/installer.txt"
        grep -E '^[^#[:space:]]' "$PROFILE/packages.d/installer.txt"
    } >>"$PROFILE/packages.x86_64"
fi
# Calamares 3.4.2 is built inside Laden OS. Arch does not ship it.
# The payload is only the runtime tree, copied into this build's profile.
calamares_tar=$ROOT/build/cache/calamares-3.4.2-runtime.tar
if [[ ! -f $calamares_tar ]]; then
    echo "Calamares runtime payload is missing: $calamares_tar" >&2
    exit 2
fi
tar -C "$PROFILE/airootfs" -xf "$calamares_tar"
if [[ ! -x $PROFILE/airootfs/usr/bin/calamares ]]; then
    echo "Calamares binary was not unpacked into the profile." >&2
    exit 2
fi
if [[ ! -d $PROFILE/airootfs/usr/lib/calamares/modules/unpackfs ]]; then
    echo "Calamares unpackfs module is missing from the payload." >&2
    exit 2
fi

cache_dir=$ROOT/build/pacman-cache
mkdir -p "$cache_dir"
awk -v cache="$cache_dir" '
    { print }
    /^\[options\]$/ { print "CacheDir = " cache }
' "$PROFILE/pacman.conf" >"$PROFILE/pacman.conf.new"
mv "$PROFILE/pacman.conf.new" "$PROFILE/pacman.conf"
if grep -q CacheDir "$PROFILE/airootfs/etc/pacman.conf"; then
    echo "Live pacman.conf must not contain a build CacheDir." >&2
    exit 2
fi

dest=$PROFILE/airootfs/usr/share/backgrounds/laden
mkdir -p "$dest"
rm -f "$dest/"laden-os-lets-do-it-*.png
while read -r _sum _file; do cp -a "$ROOT/branding/$_file" "$dest/"; done <"$sumfile"
if [[ $(sha256sum "$dest/laden-os-lets-do-it-v2-7680x4320.png" | cut -d' ' -f1) != b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f ]]; then
    echo "v2 8K default wallpaper hash mismatch." >&2; exit 2
fi
(
    cd "$dest"
    sha256sum -c "$sumfile"
)
if compgen -G "$dest/*emerald*" >/dev/null || compgen -G "$dest/*hp*" >/dev/null; then
    echo "Rejected artwork was copied into the profile." >&2
    exit 2
fi

cockpit_tar=$ROOT/build/cache/the-cockpit-1.1.0-linux-x86_64.tar.gz
cockpit_expected=72349d6983827d6a50acbdb5850b46aaa30213e9ecc8bb89f1e57c1d00943eb1
if [[ ! -f $cockpit_tar ]]; then
    echo "CockPit 1.1.0 tarball is not in build/cache." >&2
    exit 2
fi
cockpit_got=$(sha256sum "$cockpit_tar" | awk '{print $1}')
if [[ $cockpit_got != "$cockpit_expected" ]]; then
    echo "CockPit tarball hash does not match the published 1.1.0 hash." >&2
    exit 2
fi
mkdir -p "$PROFILE/airootfs/usr/share/laden-os/src"
cp -a "$cockpit_tar" "$PROFILE/airootfs/usr/share/laden-os/src/"

snapshot=$LOGDIR/host-identity-before.txt
{
    getent passwd root
    getent passwd laden
    if getent passwd live >/dev/null; then
        echo "host already has a live account"
        exit 2
    fi
    echo "no-live-account"
    sha256sum /etc/pacman.conf /etc/pacman.d/mirrorlist
} >"$snapshot"

# Resolve the phase-1 set against the official databases before pacstrap.
# mkarchiso 92 does not stop when rootless pacstrap fails: pacstrap -N has no
# set -e, so a failed inner unshare still lets the outer pacstrap exit 0.
preflight_db=$ROOT/build/pacman-db
mkdir -p "$preflight_db"
mapfile -t phase_packages < <(grep -E '^[^#[:space:]]' "$PROFILE/packages.x86_64")
# pacman refuses to sync unless euid is 0. The user namespace is the same
# rootless path mkarchiso uses. It does not write the host databases.
if ! unshare --map-auto --map-root-user pacman --config "$PROFILE/pacman.conf" \
    --dbpath "$preflight_db" -Sy --noconfirm --disable-sandbox; then
    echo "Could not sync the official Arch databases." >&2
    exit 1
fi
if ! unshare --map-auto --map-root-user pacman --config "$PROFILE/pacman.conf" \
    --dbpath "$preflight_db" -Sp --print-format '%n' --disable-sandbox -- \
    "${phase_packages[@]}" >"$LOGDIR/package-resolve.txt"; then
    echo "Phase-1 package resolution failed. See $LOGDIR/package-resolve.txt" >&2
    exit 1
fi

export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(date +%s)}
echo "SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH" | tee "$LOGDIR/build-phase1.env"
logfile=$LOGDIR/build-phase1.log
echo "mkarchiso-start $(date -Is)" >>"$logfile"
set +e
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE" 2>&1 | tee -a "$logfile"
status=${PIPESTATUS[0]}
set -e

{
    getent passwd root
    getent passwd laden
    if getent passwd live >/dev/null; then
        echo "host gained a live account"
    else
        echo "no-live-account"
    fi
    sha256sum /etc/pacman.conf /etc/pacman.d/mirrorlist
} >"$LOGDIR/host-identity-after.txt"
if ! cmp -s "$snapshot" "$LOGDIR/host-identity-after.txt"; then
    echo "Host identity files changed during the build. See $LOGDIR/host-identity-after.txt" >&2
    exit 3
fi
if findmnt -R "$WORK" >/dev/null 2>&1; then
    echo "Build left mounts under $WORK." >&2
    findmnt -R "$WORK" >&2 || true
    exit 3
fi
if grep -q 'Failed to install packages to new root' "$logfile"; then
    echo "pacstrap failed. mkarchiso does not stop on that error when run rootless. Log: $logfile" | tee -a "$logfile" >&2
    exit 1
fi
if (( status != 0 )); then
    echo "mkarchiso failed with status $status. Log: $logfile" | tee -a "$logfile" >&2
    exit "$status"
fi

iso=$(find "$OUT" -maxdepth 1 -type f -name 'laden-os-*.iso' -printf '%T@ %p\n' | sort -nr | awk 'NR==1 {print $2}')
if [[ -z ${iso:-} || ! -f $iso ]]; then
    echo "No ISO was produced in $OUT" >&2
    exit 1
fi
(
    cd "$OUT"
    sha256sum "$(basename "$iso")" > "SHA256SUMS-$(basename "$iso" .iso)"
)
if [[ -f $WORK/iso/laden/pkglist.x86_64.txt ]]; then
    cp -a "$WORK/iso/laden/pkglist.x86_64.txt" "$OUT/PACKAGES-$(basename "$iso" .iso).txt"
fi
{
    echo "ISO=$iso"
    echo "SHA256=$(cut -d' ' -f1 "$OUT/SHA256SUMS-$(basename "$iso" .iso)")"
} | tee -a "$logfile"
