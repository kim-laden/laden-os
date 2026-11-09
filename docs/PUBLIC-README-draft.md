# Laden OS

**Based on CachyOS and Arch Linux.** Unofficial. Not Arch Linux. Not CachyOS.

Laden OS is a Linux desktop for creators, gamers, and lab / red-team work —
one system that boots live, installs cleanly, and stays fast. Built and proven
on real hardware (ladenx), then packaged for everyone else.

> Status: **v1 preparation.** The public ISO download is not linked here yet.
> Watch [laden.no](https://laden.no/en/portfolio/laden-os/) for release news.

## What’s in the box

- **Desktop:** KDE Plasma 6.8 on Wayland
- **Kernel:** `linux-laden` (CachyOS-based sources, Laden packaging — `uname` says laden, not cachy)
- **Editions (planned):**
  - **Standard** — full graphics stack (NVIDIA / AMD / Intel) and one-click installers for the big apps, Steam included
  - **Live USB** — pentest / lab bundle ready, with easy Tailscale and RustDesk tunnels
  - **Full** — network install from the `[laden]` package repository
- **Laden tooling:** Laden Update, Kernel Manager, Scheduler, Gaming tweaks, Laden menu / dashboard
- **Installer:** Calamares (Laden configuration)

## License

Laden’s **original** tooling, metas, and docs are **MIT**, Copyright (c) 2026
Laden AS. Forks of GPL software (update / scheduler / kernel-manager /
Calamares / the kernel) keep their **upstream GPL** licenses. Logos and
Laden OS Art are **Laden AS branding** — forks must rebrand.

See [`LICENSE`](../LICENSE), [`NOTICE`](../NOTICE), and
[`docs/LICENSE-AUDIT.md`](LICENSE-AUDIT.md).

## Repository layout

| Path | Role |
|------|------|
| `packages/` | PKGBUILDs for the `[laden]` repo |
| `profile/` | archiso profiles |
| `rebrand/`, `branding/` | Identity and art |
| `scripts/` | Build, test, and scan helpers |
| `docs/` | Design and release docs |

## Building (developers)

You need an Arch-based host, archiso, and the usual packaging tools. Details
live in `docs/DEVELOPMENT.md`. Do not publish an ISO until
`docs/SECRETS-SCAN-REPORT.md` is clean for that build and Laden has signed off.

```bash
# Example only — see docs for the real release path
bash packages/build-repo.sh
# ISO build is a separate, explicit release step
```

## Credits

Based on **CachyOS** and **Arch Linux**. Calamares, the Linux kernel, and many
desktop components belong to their upstream authors. Full attribution:
[`NOTICE`](../NOTICE).

## Contact

Laden AS — [laden.no](https://laden.no) — admin@laden.no
