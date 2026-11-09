# Laden OS license audit (v1 prep)

Date: 2026-11-10 (Europe/Oslo). Preparation only — no ISO build, no repo
visibility change, no package rebuild.

Root policy: **MIT, Copyright (c) 2026 Laden AS**, for Laden original work,
unless a path below says otherwise. Full texts live under `LICENSES/`.

## Directory / package table

| Path | Origin | License | Notes |
|------|--------|---------|-------|
| `LICENSE`, `NOTICE`, `CREDITS`, `LICENSES/` | Laden | MIT (+ bundled upstream license texts) | Root MIT covers original work only |
| `scripts/` (Laden-written) | Laden | MIT | Host paths like `/home/laden/...` in wallpaper helpers are hygiene issues, not license issues |
| `scripts/vm-0.2.sh`, `scripts/vmctl.py` | Editions worker (uncommitted) | MIT intended | Not part of this commit |
| `tests/` | Laden | MIT | Includes intentional `tests/fixtures/fake-key.pem` for scanner tests |
| `docs/` | Laden | MIT | |
| `assessment/` | Laden (host package lists) | MIT | Machine inventory; review before public |
| `packages/metas/gen-metas.py` | Laden | MIT | Emits meta PKGBUILDs |
| `packages/laden-menu/` | Laden original | **MIT** | Dashboard / XDG menu |
| `packages/laden-gaming-tweaks/` | Laden original | **MIT** | |
| `packages/laden-desktop/`, `-gaming/`, `-creator/`, `-streaming/`, `-pentest/`, `-full/` | Laden metas | **MIT** | Depend on third-party packages that keep their own licenses at install time |
| `packages/laden-mirrorlist/` | Laden | **MIT** | Still points at `file:///srv/laden-repo` for local builds |
| `packages/laden-keyring/` | Laden packaging + **public** signing key | **MIT** | Secret key must never enter git (not present) |
| `packages/laden-desktop-settings/` | Laden original (+ Breeze colors) | **MIT** (PKGBUILD) | `LadenDark.colors` is **LGPL-2.0-or-later** |
| `packages/laden-branding/` | Laden scripts + art | **MIT** + **LicenseRef-LadenAS-Branding** | Scripts/hooks MIT; logos/wallpapers/plymouth branding reserved |
| `packages/laden-wallpapers-32k/` | Laden OS Art | **LicenseRef-LadenAS-Branding** | Not MIT |
| `branding/` | Laden OS Art (AI-assisted + procedural) | **LicenseRef-LadenAS-Branding** | Recommend keep trademarked; optional future CC BY-NC-ND 4.0 |
| `rebrand/assets/icons/`, `wallpapers/`, `plymouth/`, `limine/`, splash | Laden branding | **LicenseRef-LadenAS-Branding** | Forks must rebrand |
| `rebrand/assets/LadenDark.colors`, look-and-feel colors | Adapted from KDE Breeze | **LGPL-2.0-or-later** | Upstream SPDX copyright lines retained |
| `rebrand/` scripts | Laden | MIT | `rebrand/lib/reapply-branding` hardcodes `/home/laden/Projects/...` (fix before public) |
| `packages/laden-update/` | Fork of CachyOS **cachy-update** (GPL-3) / Arch-Update | **GPL-3.0-or-later** | Upstream LICENSE verified GPL-3; see `packages/laden-update/LICENSE` |
| `packages/laden-scheduler/` | Fork of CachyOS **scx-manager** | **GPL-3.0-or-later** | Upstream LICENSE verified GPL-3 |
| `packages/laden-kernel-manager/` | Fork of CachyOS **kernel-manager** | **GPL-3.0-or-later** | Upstream LICENSE verified GPL-3 |
| `packages/laden-calamares/` | Rebuild of **cachyos-calamares** / Calamares | **GPL-3.0-or-later** | Upstream package metadata GPL-3.0-or-later |
| `packages/laden-calamares-config/` | Laden installer config for Calamares | **GPL-3.0-or-later** | Files already SPDX GPL-3.0-or-later; keep GPL (do not MIT-relicense) |
| `packages/linux-laden/` | Linux kernel via CachyOS sources | **GPL-2.0-only** | Cannot be MIT |
| `profile/laden-os/`, `profile/laden-os-0.2/` | archiso releng-derived + Laden | **GPL-3.0-or-later** (archiso lineage) for profile templates; Laden overlay scripts MIT-compatible but ship with GPL profile | Do not strip archiso credit |
| `third_party/cockpit/` | Checksums only | N/A | Kali CockPit ISO remains unpublished |
| `build/` | Local artifacts | gitignored | Not published |
| `repo/` | Built packages | gitignored | Not published |
| Root `LADEN-OS-GROK-BUILD-PROMPT*.md` | Internal build briefs | MIT or omit from public tree | Consider dropping before public; no secrets found |
| Root `ladenos.png`, `laden-emerald-hp-*.png` | Branding / early art | Branding; emerald HP png gitignored | |

## Artwork / AI note

Laden OS Art is AI-assisted and procedurally composed for Laden AS. There is
no third-party stock-font or icon pack in-tree (no `.ttf`/`.otf` found). Tray
and app icons are Laden PNGs/SVGs. **Recommendation:** keep art and logos as
`LicenseRef-LadenAS-Branding` (all rights reserved / trademark), or later
publish wallpapers under **CC BY-NC-ND 4.0** (`LICENSES/CC-BY-NC-ND-4.0.txt`)
while keeping the wordmark reserved. AI provider terms (if a hosted model was
used for any layer) should be checked by Laden before commercial redistribution
of the masters; composition copyright is claimed by Laden AS as branding.

## Third-party fonts / icons

None vendored in this repository. Runtime desktops pull fonts/icons from Arch
packages (their licenses apply on the installed system).

## PKGBUILD `license=()` status after this prep

Updated to MIT (pkgrel bumped): laden-menu, laden-gaming-tweaks, laden-desktop,
laden-gaming, laden-creator, laden-streaming, laden-pentest, laden-full,
laden-keyring, laden-mirrorlist; metas generator emits MIT.

Updated dual / branding: laden-branding (`MIT` + `LicenseRef-LadenAS-Branding`),
laden-wallpapers-32k (`LicenseRef-LadenAS-Branding`).

Left unchanged (already correct): laden-update, laden-scheduler,
laden-kernel-manager, laden-calamares, linux-laden, laden-calamares-config.

Updated: `packages/laden-desktop-settings/PKGBUILD` is **MIT** (pkgrel 7).
when that worker’s changes land.
