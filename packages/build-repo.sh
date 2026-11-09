#!/usr/bin/env bash
# Build all laden-* packages as the normal user, sign them and the [laden]
# repo database, verify signatures. No sudo. Build dirs are cleaned.
#   bash packages/build-repo.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
REPO="${LADEN_REPO_DIR:-${ROOT}/repo/x86_64}"
KEY="${LADEN_GPGKEY:-BE87AF39CC3C4610DEA910EC106B6FC0D1FF397F}"
PKGS=(laden-keyring laden-mirrorlist laden-branding laden-desktop-settings)
[[ $EUID -ne 0 ]] || { echo "run as your user, not root" >&2; exit 1; }
gpg --list-secret-keys "$KEY" >/dev/null || { echo "signing key $KEY not in ~/.gnupg" >&2; exit 1; }
mkdir -p "$REPO"
export PACKAGER="Laden OS Repo <admin@laden.no>" GPGKEY="$KEY"
export BUILDDIR="${TMPDIR:-/tmp}/laden-makepkg"   # keep src/pkg out of the tree
for p in "${PKGS[@]}"; do
  echo "==> $p"
  ( cd "$HERE/$p" && makepkg -f --clean --cleanbuild --sign --nodeps --noconfirm PKGDEST="$REPO" )
done
rm -rf "$BUILDDIR"
cd "$REPO"
# newest file per package only
files=()
for p in "${PKGS[@]}"; do
  f=$(ls -1t "$p"-[0-9]*.pkg.tar.zst | head -1); files+=("$f")
done
repo-add --sign --key "$KEY" --verify --remove laden.db.tar.zst "${files[@]}"
echo "==> verifying signatures"
for f in "${files[@]}" laden.db.tar.zst laden.files.tar.zst; do
  gpg --verify "$f.sig" "$f" 2>&1 | grep -E 'Good signature|BAD' | sed "s|^|$f: |"
done
echo "==> repo: $REPO"; ls -la "$REPO"
