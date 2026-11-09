# Implementation plan

## Phase 0 — source profile

Done in the tree: archiso profile, official-repo pacman config, os-release hook, locked live user, wallpaper hook, serial status, identity key service, secret scanner, and Calamares stub. Unit tests cover the scanner, the layout helper, and profile hygiene.

## Phase 1 — smallest live desktop

Build `packages.x86_64` with `scripts/build-iso.sh 1`. Boot the ISO in QEMU with KVM, no NIC, and no physical disk:

1. BIOS firmware, then a reset, and confirm the proof file is gone and the identity fingerprint changed.
2. The same test with OVMF.
3. Record uptime, memory, ISO size, and the serial status in `docs/TEST-REPORT.md`.
4. Extract the squashfs and run `scripts/scan-secrets.py`. A clean scan is required before any "release-ready" claim. A boot pass is required before any "it boots" claim.

## Phase 2 — CockPit, PipeWire confirmation, second kernel

Only after phase 1 has a boot result.

- Download `the-cockpit-1.1.0-linux-x86_64.tar.gz`, require SHA-256 `72349d6983827d6a50acbdb5850b46aaa30213e9ecc8bb89f1e57c1d00943eb1`, and install with upstream `install.sh` inside the image build, not on the host.
- Set Intel capture off in the product config and in CockPit's own configuration. Ship no SSH targets.
- Add `linux-lts` and a second boot entry. Record which kernel is the default (`linux`).
- Confirm PipeWire is running in the live session. The packages are already in phase 1 so the desktop has a session sound server; the runtime check is still untested.

## Phase 3 — curated profiles

Add `packages.d/creator.txt`, `gamer.txt`, and `lab.txt` only after each name still exists and its license is recorded. Prefer official Arch packages. Do not run BlackArch `strap.sh`. Do not install the whole BlackArch repository. Record NVRs in `PACKAGES-LAB.txt`. Keep game libraries off the ISO.

## Phase 4 — installer

Calamares onto an empty qcow2 only. Human review of partition, EFI, and encryption screens. Remove live autologin, the live sudo rule, and the live polkit rule from the installed system.

## Phase 5 — publication

SBOM from the package list, checksums, scanner report, and a hardware matrix of Pass / Fail / Untested. No GPG signature until a release key exists outside this tree. No USB write. No host bootloader change.
