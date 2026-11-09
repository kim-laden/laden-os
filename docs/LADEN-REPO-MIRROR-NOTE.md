# `[laden]` repo URL — change needed for v1 (do not apply yet)

## Current (ladenx and packages)

`/etc/pacman.d/laden-mirrorlist` and `packages/laden-mirrorlist/laden-mirrorlist`:

```
Server = file:///srv/laden-repo/$arch
#Server = https://laden.no/repo/$arch
```

Also referenced by `profile/laden-os-0.2/pacman.conf` as
`Server = file:///srv/laden-repo/$arch` for local ISO builds.

## Required for public v1

1. Host a signed package mirror over **HTTPS** (planned: `https://laden.no/repo/$arch`).
2. Flip `laden-mirrorlist` so the https Server is active and the file:// line is
   local-dev only (or behind an install-time toggle).
3. Rebuild/publish `laden-mirrorlist` and ensure installed systems
   `pacman -Syu` pick it up.
4. Keep SigLevel = Required DatabaseRequired; only the **public** key ships in
   `laden-keyring`.

**This prep intentionally does not change those files.**
