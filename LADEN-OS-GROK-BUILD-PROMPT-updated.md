# Laden OS — Grok Build Prompt (paste-ready)

**Document role:** Research brief for humans/SchnOOdle + **complete build specification** for Grok Build.  
**This chat does not build the OS** — the prompt below is the deliverable.  
**Researched:** 2026-11-08 (Europe/Oslo). Revised same day for Lab-in-ISO, DM wording, and phase metrics.  
**Brand:** Laden OS — unofficial, **based on Arch Linux**. Do not claim to be Arch Linux or use Arch trademarks as product identity.

---

## Part A — Research recommendation (relay / human)

### Verdict
Build with **archiso + KDE Plasma (Wayland-first) on baseline `x86_64` (generic Arch ABI)**. Treat ladenx as a **favored reference workstation** for workflow ideas only — not a clone target and not a CachyOS-v3 portable baseline. Ship **live immutable squashfs + overlay (fresh boot by default)**; optional persistence; optional Calamares install.

**Lab/pentest priority:** the live ISO must be **usable offline for curated lab work** (capture, triage, common scanners) with a **reviewed, pinned BlackArch (or equivalent) package set baked into the image** via a clean build-chroot repo + keyring + signature verification. That is **not** “BlackArch cannot be integrated at build time.” Full BlackArch catalogue expansion remains **post-install opt-in**. Do not run unchecked `strap.sh` during unattended install; do not ship “all tools.”

### Why not CachyOS-v3 as the public ISO baseline
CachyOS optimized repos target x86-64-v3/v4; a v3-tuned system is not portable to baseline CPUs. Laden OS must boot ordinary creator/lab machines. ladenx-style packages inspire profiles; they must not drag in host GPU env hacks, machine-id, SSH presets, or personal paths (see prior CockPit Kali Live publication failures).

### Official sources (HTTP 200 verified this revision)
1. https://wiki.archlinux.org/title/Archiso  
2. https://man.archlinux.org/man/mkarchiso.1.en  
3. https://wiki.archlinux.org/title/USB_flash_installation_medium  
4. https://www.blackarch.org/downloads.html  
5. https://calamares.codeberg.page/docs/deploy-guide/  
6. https://wiki.archlinux.org/title/NVIDIA  
7. https://wiki.archlinux.org/title/Steam  
8. https://wiki.archlinux.org/title/PipeWire  

Workflows matter more than volatile ISO kernel version numbers; re-resolve packages **on build day**.

### Verified host reference (ladenx) — packages ≠ active services
| Item | Evidence (2026-11-08) |
|------|------------------------|
| Active display manager | `display-manager.service` → **plasmalogin** (active/enabled). **`sddm` is installed but inactive/disabled.** |
| DE packages present | `plasma-desktop 6.8.2`, `kwin 6.8.2`, Plasma Wayland session in use |
| Shell / UX packages | `fish`, `fastfetch`, `btop`, `wezterm` |
| Audio packages | `pipewire`, `wireplumber` |
| GPU packages | `nvidia-open-dkms`, `mesa`, `vulkan-intel` (hybrid-capable host) |
| Games packages | `steam`, `lutris`, `gamemode`, `mangohud` (+ CachyOS Proton variants on host — **baseline ISO should use Arch `steam` + Steam-delivered Proton**, not require CachyOS Proton) |
| Creator packages (subset) | e.g. `blender`, `kdenlive`, `obs-studio-browser`, `ardour` — curate; license-check each |
| Lab on host | `blackarch-keyring` / mirrorlist present — inspiration only; ISO uses **pinned reviewed set** |
| Branding wallpaper | **Default shipping wallpaper is 8K** `laden-os-lets-do-it-7680x4320.png` (7680×4320), slogan **"Let's do it!"**, SHA-256 `250fe811ba53b98f9284d422fe72a48438493b7e0a7d7f4a058a44a99064a35e`. Plasma/KWin will scale it down on lower-res screens. Keep 1080p/4K/ultrawide variants in branding for optional user override (ultrawide is **not** auto-selected). Honest note: 8K is **AI-upscaled**, not a native 8K capture. Previous HP emerald asset is art/workflow reference only. **No hardcoded output names.** |

**Display manager for Laden OS:** recommend a **verified-feasible** Plasma-friendly DM (evaluate **plasmalogin** vs **SDDM** against current Plasma packaging on build day; pick one, document why, and test Wayland session start). Do not assume “sddm installed on ladenx ⇒ SDDM is what Laden OS must use.”

### CockPit 1.1.0 — verified this revision (not 1.0.0-only)
- Portfolio HTTP 200: https://laden.no/en/portfolio/the-cockpit/ (shows v1.1.0)  
- GitHub tag HTTP 200: https://github.com/kim-laden/the-cockpit/releases/tag/v1.1.0  
- Linux tarball SHA-256: `72349d6983827d6a50acbdb5850b46aaa30213e9ecc8bb89f1e57c1d00943eb1`  
- Manifest: https://github.com/kim-laden/the-cockpit/releases/download/v1.1.0/SHA256SUMS-1.1.0.txt  
- **Reject** historical staging hash `47d0abb7…` (contaminated personal/cache path era).  
- MIT © Laden AS; keep WezTerm MIT + third-party notices. Before any public OS that vendors CockPit: reproduce from audited tag + matching artifact hashes.

### Publication lessons (apply; do not ship internal scan trees)
Prior CockPit Kali Live scan blocked on embedded service private keys, skel SSH presets, and default known live passwords. Apply the same gates. Do **not** publish internal extractor paths or privacy-sensitive build-report roots in the public Laden OS source tree. Held Kali ISO stays out of scope / not for redistribution.

### Branding direction (owner update, 2026-11-08)
Use the newly created Laden OS wallpaper with the slogan **"Let's do it!"** and more details to discover. Do not ship the old HP wallpaper. The refreshed set contains 1920×1080, 3840×2160, 3440×1440 ultrawide and 7680×4320 variants. These are derived/AI-upscaled assets; do not claim native 4K or native 8K artwork. Retain normal asset provenance/licensing checks in the publication gate.

### Candidate curated Lab tools (verify availability + license at build; pin exact versions then)
Offline-useful examples to resolve in the build chroot (adjust if renamed/unavailable): `wireshark-cli` / `wireshark-qt`, `tcpdump`, `nmap`, `sqlmap`, `hashcat` or `john`, `binwalk`, `foremost` or `scalpel`, `testdisk`/`photorec`, `sleuthkit`, `exiftool`, `radare2` or `ghidra` (size/license check), `impacket` (Python packaging check), `aircrack-ng` (lab-only docs). Prefer BlackArch packages **only when** signatures verify and the package is on the reviewed pin list — otherwise use official Arch packages of the same tool.

---

## Part B — PASTE INTO GROK BUILD

```
You are Grok Build. Build **Laden OS**: an unofficial Arch Linux–based live USB (optional disk install), branded for Laden AS. Audiences: creators, gamers, and lab/pentesters who need a **live-first** system. Use the “ladenx” workstation as a **favored reference for workflows only** — do not clone host GPU env, CachyOS-v3 repos, machine-id, SSH presets, Wi-Fi, tokens, personal paths, or private configs.

══════════════════════════════════════════════════════════════════
0) NON-GOALS / HARD PROHIBITIONS
══════════════════════════════════════════════════════════════════
- Do NOT write physical USB sticks, host disks, or ladenx partitions.
- Do NOT claim to be Arch Linux; brand “Laden OS (based on Arch Linux)”.
- Do NOT use CachyOS x86-64-v3/v4 repos as the portable baseline.
- Do NOT embed: personal SSH configs/endpoints, known_hosts, password hashes, cloud tokens, MOK/Secure Boot private keys, machine-id copies, Wi-Fi PSKs, developer home paths, host __pycache__, journal/evidence contents, or any private key PEM used as a live secret.
- Service keys (e.g. any lab simulator certs): generate on first boot; never ship private keys in the squashfs.
- Do NOT enable SSH/VNC/RDP by default on live or installed systems.
- Do NOT auto-enable CockPit Intel capture, telemetry, or uploads.
- Do NOT run unchecked BlackArch strap.sh during unattended install; do NOT ship the entire BlackArch set.
- Do NOT use docker.sock / docker group as a build privilege workaround. Clean rootful archiso host only.
- Do NOT reuse/redistribute the held CockPit Kali Live ISO.
- Do NOT promise Proton Anti-Cheat compatibility, universal GPUs, or Secure Boot success without a real public process (never ship signing private keys).
- Do NOT put privacy-sensitive internal scan trees or host absolute build roots into the public source repo.

══════════════════════════════════════════════════════════════════
1) PRODUCT DEFINITION
══════════════════════════════════════════════════════════════════
Name: Laden OS  
Primary: Live USB. Optional: Calamares install.  
Arch: x86_64 baseline (generic Arch packages).  
Desktop: KDE Plasma + KWin Wayland (Xwayland ok).  
Display manager: choose **plasmalogin or SDDM** after verifying current Plasma packaging feasibility on build day; document the choice and test Wayland greeter→session. (Reference host runs plasmalogin; SDDM may be installed elsewhere without being active — do not cargo-cult.)

Shell UX inspirations (packages, not host dotfiles): fish, fastfetch, btop, The CockPit.
Default wallpaper (**8K is the OS default**; generic path only):
  /usr/share/backgrounds/laden/laden-os-lets-do-it-7680x4320.png
  SHA-256: 250fe811ba53b98f9284d422fe72a48438493b7e0a7d7f4a058a44a99064a35e
  Slogan "Let's do it!" is in the artwork. Set this file as the Plasma **default** image wallpaper for all sessions. On lower-resolution screens the compositor **scales it down** — do **not** auto-swap to another variant. Honesty: the 8K asset is **AI-upscaled**, not a native 8K capture (state in USER-GUIDE / release notes).

Wallpaper variants (same artwork/slogan; install all under /usr/share/backgrounds/laden/ for **optional user override only** — never auto-select ultrawide or 1080p over the 8K default):
  laden-os-lets-do-it-7680x4320.png — DEFAULT — SHA-256 250fe811ba53b98f9284d422fe72a48438493b7e0a7d7f4a058a44a99064a35e
  laden-os-lets-do-it-3840x2160.png — optional 4K — SHA-256 b37e9c115fd62cc8cdc2eb5b950d2003650b11c338827d2aedb4a3c24c3ec86b
  laden-os-lets-do-it-1920x1080.png — optional 1080p — SHA-256 ada30ea453e2197246a021e965a900fb2c0818b7135bbe7f86198cc3b2412bf8
  laden-os-lets-do-it-3440x1440.png — optional ultrawide — SHA-256 ea2f0887b2fb299cb153c49c87ccf514c35c056a8200381e873b8d6466f773ee
  Preserve user wallpaper overrides once the user changes them. **Detect outputs at runtime** only for layout helpers (btop/fish). **No hardcoded connector names (no DP-5/HDMI-A-1).**

Live defaults:
- Immutable squashfs + overlayfs; changes discarded on reboot unless user enables documented persistence.
- Fresh boot every power cycle by default.

Install:
- Calamares with Laden configs under /etc/calamares (framework + separate config per Calamares deploy guide).
- Human disk selection; EFI/dual-boot/encryption warnings. Tests use empty virtual disks only.

Profiles:
- laden-os-base (always on live)
- laden-os-creator (PipeWire/WirePlumber; curated Blender/Kdenlive/OBS/GIMP/Inkscape etc. after license table)
- laden-os-gamer (steam + correct multilib Vulkan; gamemode; mangohud; game libraries on user storage — document, don’t bake games)
- laden-os-lab (**ON LIVE ISO**): curated offline toolset below + docs for authorized lab use only

Kernels: linux + linux-lts (+ headers for DKMS). Both in boot menu.

GPU: Mesa + vendor Vulkan stacks; NVIDIA Turing+ document nvidia-open / nvidia-open-dkms + DRM KMS for Wayland (ArchWiki). Hybrid/PRIME documented, not host-copied. VR optional later.

Audio: PipeWire + WirePlumber + pipewire-pulse (+ alsa/jack bridges as needed).

Python: system python3; per-project venvs; no break-system-packages globals.

AI agents (modular): menu/docs for bring-your-own CLI agents (e.g. patterns like CockPit’s optional tutor discovery). **Official vendor logins only; credentials never shipped; no auto-uploads; nothing runs until the user installs + signs in themselves.**

Hardware accessories (optional, documented only in v0.1 if drivers are clear):
- Flipper Zero / WiFi Pineapple: document supported host packages, udev permissions via **non-privileged groups**, and that firmware/cloud accounts stay user-owned. No embedded device creds. Skip packaging if license/driver story is unclear — leave as “supported when user installs X.”

Lab tools ON the live image (curated, pinned, signature-verified):
- Integrate BlackArch (and/or Arch) packages **during the archiso build chroot** with official keyring install, mirrorlist, and pacman signature verification — consistent full sync for the pin set (`pacman -Sy` then install **exact pinned packages**, not a partial-upgrade Frankenstein).
- Minimal curated group examples to resolve at build (replace with exact repo names after `pacman -Ss` / BlackArch group query): PCAP/capture (wireshark/tcpdump), recon (nmap), web lab (sqlmap), crypto triage (hashcat or john), file/carving (binwalk, testdisk/photorec, sleuthkit, exiftool), RE as size allows (radare2; ghidra only if license/size acceptable). Prefer Arch official when equivalent.
- Record every pinned package NVR in PACKAGES-LAB.txt.
- Optional **post-install** path: expand toward broader BlackArch catalogue with hash-verified strap.sh + required full system upgrade (per blackarch.org/downloads.html). Never auto-strap on first boot.
- No attack playbooks; no default open listeners; guest “shared folder intel” disabled in default test VMs; avoid automounting foreign filesystems by default (forensics-safe).

══════════════════════════════════════════════════════════════════
2) BUILD TECHNOLOGY
══════════════════════════════════════════════════════════════════
- archiso / mkarchiso; customize profile from releng → `laden-os`.
- Re-resolve mirrors and package versions on build day; never invent versions.
- Prefer tmpfs work dir if RAM allows; clean builder; no docker.sock tricks.
- Output hybrid BIOS+UEFI ISO.
- Optional GPG-sign artifacts with a release key whose **private** half never enters the tree; publish public key + SHA256SUMS. Secure Boot: document unsigned limitation unless a real MOK story exists without private keys in-tree.

BlackArch at build (accurate):
- Allowed and expected for the curated pin set via pacman in the build chroot after keyring+repo configuration and signature verification.
- Full-repo “install everything” and unattended strap are out of scope for the ISO.
- strap.sh remains a **documented optional host expansion** after install (verify SHA1 from blackarch.org/downloads.html at the time you document it).

Calamares: package binary separately from /etc/calamares branding; human-reviewed installer UX.

══════════════════════════════════════════════════════════════════
3) THE COCKPIT 1.1.0 (MANDATORY PIN — VERIFIED)
══════════════════════════════════════════════════════════════════
Use published The CockPit 1.1.0 only:
- https://laden.no/en/portfolio/the-cockpit/
- https://github.com/kim-laden/the-cockpit/releases/tag/v1.1.0
- the-cockpit-1.1.0-linux-x86_64.tar.gz
- SHA-256: 72349d6983827d6a50acbdb5850b46aaa30213e9ecc8bb89f1e57c1d00943eb1
- Manifest: SHA256SUMS-1.1.0.txt on that release
Reject staging hash 47d0abb7…. MIT © Laden AS; preserve WezTerm MIT notices.
Install via upstream install.sh into generic paths (not a copy of anyone’s home). Capture OFF by default. Empty example connections only.

══════════════════════════════════════════════════════════════════
4) SECURITY / PUBLICATION GATE
══════════════════════════════════════════════════════════════════
Before any public ISO:
1. Extract squashfs; scan for private keys, cloud tokens, wifi PSKs, .git-credentials, personal known_hosts, developer /home paths in bytecode.
2. Negative fixture in CI proves the scanner catches a planted then removed fake key.
3. Legitimate upstream *unused* test fixtures: prefer removal; if kept, document and ensure they are not loaded as live secrets. Live service keys must be first-boot generated.
4. Locked accounts; no default known live passwords.
5. Live autologin if used: local seat only; document risk; installed system forces user setup.
6. sshd disabled/masked; verify no admin listeners on fresh live boot.
7. Two VM boots → different first-boot key fingerprints.
8. SBOM + SHA256SUMS + PACKAGES.txt + PACKAGES-LAB.txt + os-release version parity.
9. Do not publish internal extractor directories or privacy-sensitive report roots in the public repo.

══════════════════════════════════════════════════════════════════
5) PHASED DELIVERY (FIRST RELEASE FOCUS)
══════════════════════════════════════════════════════════════════
Version scheme: start `0.1.0-live` until Calamares + matrix pass.

Phase 0 — Profile skeleton: archiso laden-os profile, branding paths, os-release, empty Calamares config stubs, LICENSE/THIRD_PARTY.

Phase 1 — Minimal live ISO (gate):
- QEMU BIOS + UEFI (OVMF) boot to Plasma Wayland.
- fish, fastfetch, btop, NetworkManager, firefox, wallpaper via generic path.
- Measure and **record** (no invented pass/fail time budget): time-to-greeter, time-to-Plasma-shell, ISO size, RAM used at idle after login (free -h / systemd-cgtop notes). Attach numbers in TEST-REPORT.md.
- Prove overlay freshness: create ~/PROOF; reboot; PROOF absent.

Phase 2 — CockPit + PipeWire + dual kernel:
- Hash-verify CockPit 1.1.0; cockpit --version; capture OFF.
- PipeWire user stack starts; note audio device visibility in VM.
- linux and linux-lts both boot; record which was default.

Phase 3 — Lab-on-live + Creator/Gamer metapackages:
- Curated Lab packages installed and runnable offline (e.g. nmap --version, tshark/tcpdump -h, sqlmap --version as applicable).
- Creator/Gamer groups build; Steam library path documented; license table for Creator set.
- AI agent “bring your own” docs/menu stubs; Flipper/Pineapple docs if included.

Phase 4 — Calamares:
- Install to empty qcow2; reboot from virtual disk; human reviews partition/EFI/encryption screens.
- Record install duration and target disk size used.

Phase 5 — Publication pipeline:
- Reproducible inputs; SBOM; checksums; safety report; release notes; public verify key.
- Hardware matrix rows: Pass / Fail / Untested only — never claim untested as Pass.

══════════════════════════════════════════════════════════════════
6) ACCEPTANCE TESTS
══════════════════════════════════════════════════════════════════
A. BIOS + UEFI ISO boot (run_archiso / QEMU + OVMF).
B. Offline live boot (NIC down) reaches Plasma.
C. Freshness proof (PROOF file gone after reboot).
D. Persistence only if documented and separately tested.
E. sshd disabled; no ssh listener.
F. Unique first-boot keys across two boots.
G. CockPit hash + 1.1.0 + capture OFF + no personal SSH targets.
H. Secrets scan clean per gate rules.
I. Lab offline: at least capture + nmap (+ sqlmap if pinned) run help/version without network.
J. Calamares empty-disk only; human UI review.
K. Secure Boot: unsigned documented.
L. GPU matrix honest (virtio; Intel/AMD/NVIDIA if hardware available).
M. No automatic intel/journal logging.
N. Optional layout helper does not hardcode monitor connector IDs.

══════════════════════════════════════════════════════════════════
7) DELIVERABLES
══════════════════════════════════════════════════════════════════
1. Clean archiso profile + scripts (no secrets, no host paths)
2. ISO + SHA256SUMS + SBOM + PACKAGES.txt + PACKAGES-LAB.txt
3. TEST-REPORT.md with recorded metrics and commands actually run
4. PUBLICATION-SAFETY-REPORT.md (methodology + results; no dumping secret contents)
5. USER-GUIDE.md: live vs install, persistence, rolling `pacman -Syu` (no partial upgrades), Lab tools, optional BlackArch expansion, Steam libraries, CockPit, AI BYO creds, accessory hardware, Secure Boot limits
6. Branding under /usr/share/backgrounds/laden/ + greeter/Calamares themes

══════════════════════════════════════════════════════════════════
8) UPDATES
══════════════════════════════════════════════════════════════════
- Rolling Arch education: always full upgrades.
- Live product refreshes by rebuilding the ISO from the profile.
- Installed systems may use Btrfs snapshots/rollback; do not inflate the live image for that.
- CockPit upgrades via published hashed artifacts only.

Start Phase 0–1. Record metrics. Stop for human review before Calamares disk writes if unsure. Prefer a usable curated live Lab over a maximal unmaintainable image.
```

---

## Part C — Packet index

| Path | Purpose |
|------|---------|
| `/workspace/laden-os/LADEN-OS-GROK-BUILD-PROMPT.md` | This file (research + paste-ready prompt) |
| `/workspace/laden-os/branding/laden-os-lets-do-it-7680x4320.png` | **Default** Laden OS wallpaper (8K, AI-upscaled); SHA-256 `250fe811ba53b98f9284d422fe72a48438493b7e0a7d7f4a058a44a99064a35e` |
| `/workspace/laden-os/SHA256SUMS-1.1.0.txt` | CockPit 1.1.0 checksums |

**Not produced:** Laden OS ISO, USB write, repo push, host config changes.
