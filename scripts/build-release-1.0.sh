#!/bin/bash
# SPDX-License-Identifier: MIT
# Build the Laden OS 1.0.0 Standard ISO from profile/laden-os-1.0 in a fresh
# work directory (build/release-1.0.0-<stamp>). Rootless (user namespace),
# low priority (nice 19 / ionice idle), stops if free disk space drops below
# 40 GiB. Does not publish anything and never writes a block device.
set -euo pipefail
if pgrep -x cs2 >/dev/null || pgrep -f 'Counter-Strike' >/dev/null; then
  echo "CS2 is running — refusing to build (pause until the game exits)." >&2; exit 3
fi
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=1.0.0-standard
NAME=laden-os-${VERSION}-x86_64.iso
FINAL=$ROOT/build/out
STAMP=$(date +%Y%m%d-%H%M%S)
REL=$ROOT/build/release-1.0.0-$STAMP
WORK=$REL/work OUT=$REL/out PROF=$REL/profile CACHE=$REL/pkgcache LOG=$REL/build.log
MIN_FREE_GB=40
TOOLS=$ROOT/build/host-tools/usr/bin
REPO=/srv/laden-repo/x86_64

free_gb() { df -P --block-size=1G "$ROOT" | awk 'NR==2{print $4}'; }
[[ -e $FINAL/$NAME ]] && { echo "refusing to overwrite $FINAL/$NAME" >&2; exit 2; }
(( $(free_gb) >= MIN_FREE_GB + 20 )) || { echo "need >= $((MIN_FREE_GB+20)) GiB free, have $(free_gb)" >&2; exit 2; }
[[ -x $TOOLS/mkarchiso ]] || { echo "archiso host tools missing in $TOOLS" >&2; exit 2; }
export PATH="$TOOLS:$PATH"
mkdir -p "$WORK" "$OUT" "$CACHE"
echo "release dir: $REL" | tee "$LOG"

cp -a "$ROOT/profile/laden-os-1.0" "$PROF"
air=$PROF/airootfs

# 1. Snapshot of the signed [laden] repo (only the versions in the db) so the
#    live system and installed systems can use it offline (/srv/laden-repo).
mkdir -p "$air/srv/laden-repo/x86_64"
cp -a "$REPO"/laden.{db,files}{,.sig} "$REPO"/laden.{db,files}.tar.zst{,.sig} "$air/srv/laden-repo/x86_64/"
bsdtar -xOf "$REPO/laden.db.tar.zst" '*/desc' | awk '/^%FILENAME%/{getline; print}' | while read -r f; do
    cp -a "$REPO/$f" "$REPO/$f.sig" "$air/srv/laden-repo/x86_64/"
done
echo "repo snapshot: $(ls "$air/srv/laden-repo/x86_64" | wc -l) files" | tee -a "$LOG"

# 2. limine-mkinitcpio-hook package (signed by CachyOS) for offline installs.
mkdir -p "$air/usr/share/laden-installer/pkgs"
url=$(pacman -Sp limine-mkinitcpio-hook | grep -m1 '/limine-mkinitcpio-hook-')
( cd "$air/usr/share/laden-installer/pkgs" && curl -fsSLO "$url" && curl -fsSLO "$url.sig" )

# 3. build pacman.conf: fresh cache first, the host cache read-only as a fallback.
sed -i "/^\[options\]/a CacheDir = $CACHE\nCacheDir = /var/cache/pacman/pkg" "$PROF/pacman.conf"
grep -q CacheDir "$air/etc/pacman.conf" && { echo "live pacman.conf must not have CacheDir" >&2; exit 2; }

# 4. disk + priority watchdog (ananicy may renice mksquashfs/zstd; push them back to idle priority)
( while sleep 10; do
    for pid in $(pgrep -u "$USER" -x 'mksquashfs|zstd|xorriso|pacman'); do
      renice -n 19 -p "$pid" >/dev/null 2>&1; ionice -c3 -p "$pid" >/dev/null 2>&1
    done
    if (( $(free_gb) < MIN_FREE_GB )); then
      echo "WATCHDOG: free space below ${MIN_FREE_GB} GiB, stopping mkarchiso" | tee -a "$LOG"
      pkill -TERM -f "mkarchiso -v -w $WORK" ; exit 1
    fi
  done ) & WD=$!
trap 'kill $WD 2>/dev/null || true' EXIT

export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(date +%s)}
set +e
# Feed empty answers so pacman provider prompts take the default (first) choice.
set +o pipefail
yes '' 2>/dev/null | nice -n 19 ionice -c3 mkarchiso -v -w "$WORK" -o "$OUT" "$PROF" 2>&1 | tee -a "$LOG"
st=${PIPESTATUS[1]}
set -o pipefail
# yes(1) exits 141 (SIGPIPE) after mkarchiso closes stdin; ignore that.
[[ $st -eq 141 ]] && st=0
set -e
grep -q 'Failed to install packages to new root' "$LOG" && { echo "pacstrap failed" >&2; exit 1; }
(( st == 0 )) || { echo "mkarchiso failed ($st)" >&2; exit "$st"; }
iso=$(ls "$OUT"/*.iso | head -1)
cp -a "$WORK/iso/laden/pkglist.x86_64.txt" "$OUT/PACKAGES-${NAME%.iso}.txt" 2>/dev/null || true
[[ "$iso" -ef "$OUT/$NAME" ]] || mv "$iso" "$OUT/$NAME"
( cd "$OUT" && sha256sum "$NAME" > "$NAME.sha256" )
echo "ISO: $OUT/$NAME ($(du -h "$OUT/$NAME" | cut -f1))" | tee -a "$LOG"
echo "Not copied to build/out yet: run the scan and boot tests first." | tee -a "$LOG"
