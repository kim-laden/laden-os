# Third-party software

Laden OS redistributes other people's software. Their licenses stay attached to their packages. `LICENSE` in this repository covers only the original Laden scripts and docs (MIT) and the archiso-derived profile files (GPL-3.0-or-later). It does not relicense packages or wallpapers.

| Piece | Source used on 2026-11-08 | License note |
|---|---|---|
| archiso 92 | Official extra package `archiso-92-1-any.pkg.tar.zst` | GPL-3.0-or-later. Profile boot layout follows releng. Releng's empty root password, SSH, and Arch branding are not copied. |
| arch-install-scripts 32 | Official extra | GPL-2.0-only, used as the upstream `pacstrap` |
| squashfs-tools 4.7.5 | Official extra | Build tool only |
| Arch Linux core, extra, multilib | `https://geo.mirror.pkgbuild.com` | Each package keeps its own license. The phase-1 image installs a desktop set, not a curated lab set. |
| Wallpapers | Files in `branding/` supplied with this project | No license file and no copyright metadata were supplied. They are not under the MIT grant. |
| The CockPit 1.1.0 | Not downloaded | Checksum pinned in `third_party/cockpit/SHA256SUMS-1.1.0.txt`. Not part of the image. |
| BlackArch | Not configured | `strap.sh` was not downloaded. Its published SHA-1 on 2026-11-08 was `d338a4bb95d9e09f97508da68ac9e17d963b85f6`. |
| Calamares | Not installed | Stub README only |

The build host is CachyOS. Its repositories, keyring, mirror list, and home directory are not inputs to the image.
