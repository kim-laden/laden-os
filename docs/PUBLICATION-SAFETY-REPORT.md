# Publication safety

Status on 2026-11-08: **not release-ready**. The current ISO is SHA-256 `22732d306e9d6096020e1a9399cb0c6af22f6e088a861f77e84fbbc3e33d44ad` (6402670592 bytes). The default kernel reached the Plasma desktop on BIOS and UEFI at 6144 MiB, and the overlay reset passed. CockPit 1.1.0 is in the image with capture off and no SSH targets. The Kali daily tools and the BlackArch forensic set are in this file. Creator, gamer, and Calamares are not. `scripts/scan-image.sh` exited 1: 126 hits are inside upstream lab packages, and the allowlist still names only the two GnuTLS test files. No GPG signature exists. Secure Boot is unsigned. The previous desktop-only image remains `build/out/laden-os-0.1.0-live-x86_64.iso.02e096f0`.

The extracted squashfs has no Laden OS service private key and no `/home/laden` path. GnuTLS 3.8.13-3 contains published self-test PEM blocks in `usr/bin/gnutls-cli` and `usr/lib/libgnutls.so.30.42.0`. Those are upstream test vectors, listed in `scripts/scan-allowlist.txt`. They are not keys from this workstation.

## Required before any publication claim

- ISO file produced by `scripts/build-iso.sh 1`.
- SHA-256 recorded from that file.
- Package manifest copied from the image's `pkglist`, not typed by hand.
- `unsquashfs` of the airootfs, then `scripts/scan-secrets.py` on that directory.
- The scanner must show no private key, no `/home/laden`, no empty password field, and no host SSH material.
- `etc/machine-id` in the squashfs must be the literal `uninitialized`.
- BIOS and UEFI QEMU results written in `docs/TEST-REPORT.md` from the serial logs.
- No GPG signature will be published. No release key was provided.

## Already true of the source

- The profile does not contain the workstation home, SSH config, or journal.
- The build script refuses `/dev` paths and block devices.
- CacheDir is injected only into the temporary build copy of `pacman.conf`.
- Intel capture is not implemented, so it cannot be on.
- Service identity is generated at boot into the RAM overlay.
- The HP wallpaper is not copied into the profile.

## Not claimed

Secure Boot, reproducibility against a second machine, hardware beyond the QEMU guest, and a clean scan of a built image.
