# `[laden]` repo URL

## Current

`/etc/pacman.d/laden-mirrorlist` (package `laden-mirrorlist`):

```
Server = https://laden.no/repo/$arch
#Server = file:///srv/laden-repo/$arch
```

Public mirror: https://laden.no/repo/x86_64/ (signed DB; public key via `laden-keyring`, fingerprint `BE87AF39CC3C4610DEA910EC106B6FC0D1FF397F`).

## Local builds

ISO *build-time* `profile/*/pacman.conf` lists HTTPS first and `file:///srv/laden-repo/$arch` second so a release candidate can pacstrap packages that were just built on ladenx before they are uploaded to the VPS. The mirrorlist **inside** the image (via `Include = /etc/pacman.d/laden-mirrorlist`) is HTTPS-only with file:// commented.

## Ops

After `bash packages/build-selected.sh … && sudo bash packages/publish-local-repo.sh`, copy the new `.pkg.tar.zst` + `.sig` files (and refreshed `laden.db*` / `laden.files*`) to the server under `/repo/x86_64/`. Do not rsync from ladenx with the laden_vps key unless that access is authorized.
