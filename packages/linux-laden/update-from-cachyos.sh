#!/usr/bin/env bash
# Rebuild linux-laden for the CachyOS kernel currently in the cachyos-v3 repo.
# As user (no sudo). Afterwards: sudo bash packages/publish-local-repo.sh && sudo pacman -Syu
# linux-cachyos is no longer installed, so pacman -Syu does NOT pick up new
# CachyOS kernels by itself — run this when CachyOS ships a new kernel.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)/repo/x86_64"
KEY=BE87AF39CC3C4610DEA910EC106B6FC0D1FF397F
new=$(pacman -Si cachyos-v3/linux-cachyos | awk -F': ' '/^Version/{print $2; exit}')
cur=$(. <(grep -E '^_cachy(ver|rel)=' "$HERE/PKGBUILD"); echo "${_cachyver}-${_cachyrel}")
echo "cachyos-v3: $new   linux-laden PKGBUILD: $cur"
[[ $new != "$cur" || ${1:-} == --force ]] || { echo "up to date"; exit 0; }
ver=${new%-*}; rel=${new##*-}
SRC=/tmp/laden-kpkg; mkdir -p "$SRC"
mirror=$(grep -oP "^_mirror='\K[^']+" "$HERE/PKGBUILD")
for n in linux-cachyos linux-cachyos-headers; do
  f="$n-$ver-$rel-x86_64_v3.pkg.tar.zst"
  [[ -f $SRC/$f ]] || curl -fL --retry 3 -o "$SRC/$f" "$mirror/$f"
  curl -fsL --retry 3 -o "$SRC/$f.cachysig" "$mirror/$f.sig"
done
sed -i -E "s/^_cachyver=.*/_cachyver=$ver/; s/^_cachyrel=.*/_cachyrel=$rel/" "$HERE/PKGBUILD"
cd "$HERE"
export SRCDEST=$SRC BUILDDIR=/tmp/laden-makepkg PKGDEST="$REPO" GPGKEY=$KEY PACKAGER="Laden OS Repo <admin@laden.no>"
updpkgsums
makepkg -f --cleanbuild --clean --sign --nodeps --noconfirm
rm -rf /tmp/laden-makepkg
cd "$REPO"
repo-add --sign --key "$KEY" --verify --remove laden.db.tar.zst \
  "linux-laden-$ver-$rel-x86_64.pkg.tar.zst" "linux-laden-headers-$ver-$rel-x86_64.pkg.tar.zst"
echo "Built linux-laden $ver-$rel. Next: sudo bash packages/publish-local-repo.sh && sudo pacman -Syu"
echo "Also bump KVER/PKGVER in packages/install-linux-laden.sh if you use it again."
