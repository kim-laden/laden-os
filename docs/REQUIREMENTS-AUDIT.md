# Requirements audit

Audited 2026-11-08 from `LADEN-OS-GROK-BUILD-PROMPT-updated.md`, the older prompt, the branding directory, and the official pages listed in the prompt. The updated prompt is the specification. The chat instruction matches it.

## Wallpaper filename update

`LADEN-OS-GROK-BUILD-PROMPT-v2.md` replaces the v1 filename as the default. The shipping file is `laden-os-lets-do-it-v2-7680x4320.png`, SHA-256 `b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f`. The section below records the earlier v1 decision and is not the current default.

## Resolved conflict

The older prompt makes `laden-os-lets-do-it-1920x1080.png` the default and auto-selects a variant by aspect ratio, including the ultrawide file. The updated prompt and the latest owner decision override that:

- Default file: `laden-os-lets-do-it-7680x4320.png`
- SHA-256: `250fe811ba53b98f9284d422fe72a48438493b7e0a7d7f4a058a44a99064a35e`
- Plasma scales it. The image does not auto-swap to 1080p, 4K, or ultrawide.
- Those three files are installed for a manual override.
- The 8K file is AI-upscaled, not a native 8K capture.
- `laden-emerald-hp-1920x1080.png` is not installed. Its SHA-256 is `6adbbbcfc5e33aba83c235583a8fd40a8bb915e9ffa982dd1f7d919eb674bc20`.

Local checksums of all four slogan wallpapers match `branding/SHA256SUMS-wallpapers.txt`. ExifTool found no copyright, artist, or software tags.

## Missing inputs

| Item | What the packet index says | What is in the tree |
|---|---|---|
| CockPit manifest | `/workspace/laden-os/SHA256SUMS-1.1.0.txt` | Absent at the start. Fetched from the v1.1.0 release and saved at `third_party/cockpit/SHA256SUMS-1.1.0.txt`. |
| CockPit tarball | Install the published Linux tarball | Not vendored yet. Phase 2, after a boot test. |
| Wallpaper license | Keep provenance in the publication gate | No license file was supplied with the PNGs. `LICENSE` says so. |
| Source license | Not stated | MIT for original Laden files. GPL-3.0-or-later for archiso-derived files. |
| Lab pin list | Examples, then exact NVRs at build | Names are in `packages.d/lab.txt`. NVRs are not pinned until that phase builds. |
| GPG release key | Publish a public key; private half stays out of tree | No release key was provided. The ISO will not be signed. |
| Console keymap and language | Not stated | `en_US.UTF-8` and keymap `us` until an owner choice says otherwise. |
| `ladenos.png` | Not named as a shipping asset | Not installed. |
| `obs-studio-browser` | Named as a host example in the research table | Not an official Arch package. The creator list uses `obs-studio`. |
| `libva-mesa-driver` | Implied by a Mesa VA-API stack | The package name is gone from core/extra. Mesa 26.2.6 provides VA-API. It is not listed separately. |

## Decisions made on build day

Display manager: `plasma-login-manager` 6.8.2-1 from extra. It is the current Plasma greeter, it does not pull `xorg-server`, and the reference host uses plasmalogin. SDDM 0.21.0-7 is the fallback if this greeter cannot start a Wayland session. That fallback is not the phase-1 choice.

UEFI bootloader: systemd-boot, which is what archiso 92's releng profile uses (`bios.syslinux` + `uefi.systemd-boot`). GRUB for UEFI would need `grub-mkstandalone` on the build host. That binary is not installed, and installing it would change the host. The ISO is still hybrid BIOS plus UEFI.

Build privilege: `sudo -n` is not available. mkarchiso 92 supports a normal user through `unshare --map-auto`. The build script uses the extracted archiso, arch-install-scripts, and squashfs-tools under `build/host-tools`. It does not run `pacman -S` on the host and it does not use Docker. This is the upstream rootless path, not a privilege bypass. A rootful build was not possible without a password.

Work directory: about 21 GiB RAM was available, so the work directory is on disk under `build/`, not tmpfs. `build/` is gitignored.

Repositories: the profile's `pacman.conf` points only at `https://geo.mirror.pkgbuild.com`. It does not include the host mirror list. The host is CachyOS and its pacman configuration has `cachyos-v3` repositories. Those repositories are not used. pacstrap is invoked by mkarchiso with `-M` and `-G`, so the host mirror list and host keyring are not copied into the image.

Signature level: the first build used `SigLevel = Required DatabaseRequired`. On 2026-11-08 that sync failed. `core.db` returned HTTP 200 from `geo.mirror.pkgbuild.com` (served by `umea.mirror.pkgbuild.com`). `core.db.sig`, `extra.db.sig`, and `multilib.db.sig` returned HTTP 404 from `geo.mirror.pkgbuild.com`, `mirror.pkgbuild.com`, and `berlin.mirror.pkgbuild.com`. Archiso 92's releng profile uses `Required DatabaseOptional`. The profile now uses that. Package signatures stay required. The specification asks for signature verification of packages; it does not name `DatabaseRequired`.

Rootless pacstrap: `pacstrap -N` re-executes under `unshare` and does not enable `set -e`. A failed inner install prints `Failed to install packages to new root` and the outer process still exits 0. mkarchiso then prints `Packages installed successfully` and fails later, this time on a missing `/boot`. The build script treats that pacstrap line as failure.

## Official pages checked

HTTP 200 on 2026-11-08 for the Archiso wiki, mkarchiso(1) (archiso 92), the USB installation page, BlackArch downloads, the Calamares deploy guide, and the NVIDIA, Steam, and PipeWire wiki pages. Also 200 for the CockPit portfolio page and the GitHub v1.1.0 tag.

BlackArch's documented `strap.sh` SHA-1 on that page is `d338a4bb95d9e09f97508da68ac9e17d963b85f6`. The script was not downloaded and was not run. Full-catalogue install and unattended strap stay out of the ISO.

CockPit Linux tarball SHA-256 in the fetched manifest is `72349d6983827d6a50acbdb5850b46aaa30213e9ecc8bb89f1e57c1d00943eb1`, which matches the specification.
