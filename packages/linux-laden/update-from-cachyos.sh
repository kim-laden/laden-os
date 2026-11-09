#!/usr/bin/env bash
# Rebase linux-laden onto a CachyOS linux-cachyos release.
#   bash update-from-cachyos.sh            # newest linux-cachyos in CachyOS's git
#   bash update-from-cachyos.sh <commit>   # a specific CachyOS/linux-cachyos commit
# Fetches the upstream PKGBUILD, takes the exact .config from the signed CachyOS
# x86_64_v3 headers package, regenerates PKGBUILD with laden-ize.py and updates checksums.
# Then build:  LADEN_JOBS=16 nice -n 19 ionice -c3 makepkg -f --sign   (see README)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
git clone -q --filter=blob:none https://github.com/CachyOS/linux-cachyos "$work/lc"
commit=${1:-$(git -C "$work/lc" log -1 --format=%H -- linux-cachyos/PKGBUILD)}
git -C "$work/lc" -c advice.detachedHead=false checkout -q "$commit"
up="$work/lc/linux-cachyos/PKGBUILD"
ver=$(sed -n 's/^_major=//p' "$up").$(sed -n 's/^_minor=//p' "$up"); rel=$(sed -n 's/^pkgrel=//p' "$up")
echo "CachyOS linux-cachyos $ver-$rel @ $commit"

# exact binary config from the signed CachyOS headers package
mirror=${CACHY_MIRROR:-https://at.cachyos.org/repo/x86_64_v3/cachyos-v3}
h="linux-cachyos-headers-$ver-$rel-x86_64_v3.pkg.tar.zst"
curl -fsSLo "$work/$h" "$mirror/$h"; curl -fsSLo "$work/$h.sig" "$mirror/$h.sig"
gpg --dearmor < /usr/share/pacman/keyrings/cachyos.gpg > "$work/kr.gpg"
gpgv --keyring "$work/kr.gpg" "$work/$h.sig" "$work/$h"
bsdtar -xOf "$work/$h" "usr/lib/modules/$ver-$rel-cachyos/build/.config" > "$here/config"
echo "config: $(wc -l < "$here/config") lines from $h"

python3 "$here/laden-ize.py" "$up" "$here/PKGBUILD" "$commit"
echo "$commit" > "$here/UPSTREAM_COMMIT"
cd "$here" && updpkgsums && makepkg --printsrcinfo > .SRCINFO
echo "linux-laden now at $ver-$rel. Build it (README), then install with pacman."
