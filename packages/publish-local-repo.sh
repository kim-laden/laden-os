#!/usr/bin/env bash
# Copy the built repo to /srv/laden-repo/x86_64 (root-owned, world-readable)
# so pacman's sandboxed download user (alpm) can read it. Needs sudo.
#   sudo bash packages/publish-local-repo.sh [--dry-run]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${HERE}/../repo/x86_64"; DEST=/srv/laden-repo/x86_64
DRY=0; [[ "${1:-}" == --dry-run ]] && DRY=1
[[ -f $SRC/laden.db.tar.zst ]] || { echo "no repo at $SRC — run build-repo.sh first" >&2; exit 1; }
if [[ $DRY -eq 1 ]]; then echo "DRY-RUN: rsync -a --delete $SRC/ $DEST/ (owner root, 0644)"; exit 0; fi
[[ $EUID -eq 0 ]] || { echo "needs sudo" >&2; exit 1; }
install -d -m0755 /srv/laden-repo "$DEST"
rsync -a --delete --chown=root:root --chmod=D0755,F0644 "$SRC/" "$DEST/"
echo "published to $DEST"
