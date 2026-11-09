#!/usr/bin/env bash
# Build and sign selected laden packages into repo/x86_64 (no sudo).
# Usage: bash packages/build-selected.sh pkg1 pkg2 ...
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
REPO=${LADEN_REPO_DIR:-$ROOT/repo/x86_64}
KEY=${LADEN_GPGKEY:-BE87AF39CC3C4610DEA910EC106B6FC0D1FF397F}
[[ $EUID -ne 0 ]] || { echo "run as your user, not root" >&2; exit 1; }
(( $# >= 1 )) || { echo "usage: $0 pkg..." >&2; exit 2; }
gpg --list-secret-keys "$KEY" >/dev/null
mkdir -p "$REPO"
export PACKAGER="Laden OS Repo <admin@laden.no>" GPGKEY="$KEY"
export BUILDDIR="${TMPDIR:-/tmp}/laden-makepkg"
files=()
for p in "$@"; do
  echo "==> $p"
  dir=$HERE/$p
  [[ -f $dir/PKGBUILD ]] || { echo "missing $dir/PKGBUILD" >&2; exit 2; }
  ( cd "$dir" && makepkg -f --clean --cleanbuild --sign --nodeps --noconfirm PKGDEST="$REPO" )
  f=$(ls -1t "$REPO/$p"-[0-9]*.pkg.tar.zst | head -1)
  files+=("$f")
done
rm -rf "$BUILDDIR"
cd "$REPO"
repo-add --sign --key "$KEY" --verify --remove laden.db.tar.zst "${files[@]}"
echo "==> verifying"
for f in "${files[@]}" laden.db.tar.zst; do
  gpg --verify "$f.sig" "$f" 2>&1 | grep -E 'Good signature|BAD' | sed "s|^|$f: |"
done
echo "repo: $REPO"
