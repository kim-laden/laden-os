# Laden OS

**Based on Arch Linux.** Unofficial. It is not Arch Linux.

Laden OS is a Linux desktop for creators, gamers, and lab / red-team work —
one system that boots live, installs cleanly, and stays fast. Built and proven
on real hardware (ladenx), then packaged for everyone else.

> Status: **v1 preparation.** The public ISO download is not linked here yet.
> Watch [laden.no](https://laden.no/en/portfolio/laden-os/) for release news.

## What’s in the box

- **Desktop:** KDE Plasma 6 on Wayland
- **Kernel:** `linux-laden` (`uname -r` ends in `-laden`)
- **Editions:**
  - **Standard** — full graphics stack (NVIDIA / AMD / Intel) and one-click installers for the big apps, Steam included (`laden-apps`)
  - **Red Team live USB** — pentest / lab bundle ready, with easy Tailscale and RustDesk tunnels (keys generated on the machine, never baked into the image)
  - **Full** — network install from the `[laden]` package repository
- **Laden tooling:** Laden Update, Kernel Manager, Scheduler, Gaming tweaks, Laden menu / dashboard
- **Art:** Laden OS Art (default wallpaper / lock / login) — zoom in for hidden gear and CLI eggs
- **Installer:** Calamares (Laden configuration)

## License

- **Laden original work** (tooling, metas, docs, scripts we wrote): **MIT**, Copyright (c) 2026 Laden AS — see [`LICENSE`](LICENSE).
- **GPL forks and the kernel** (`laden-update`, `laden-scheduler`, `laden-kernel-manager`, `laden-calamares` / Calamares config lineage, `linux-laden`): keep their **upstream GPL** licenses.
- **Art and branding** (logos, Laden OS Art, Plymouth/Limine splash, wordmark): **`LicenseRef-LadenAS-Branding`** — reserved to Laden AS. Forks **must rebrand**.

Details: [`NOTICE`](NOTICE), [`CREDITS`](CREDITS), [`docs/LICENSE-AUDIT.md`](docs/LICENSE-AUDIT.md).

## Repository layout

| Path | Role |
|------|------|
| `packages/` | PKGBUILDs for the `[laden]` repo |
| `profile/` | archiso profiles (Standard, Red Team, …) |
| `rebrand/`, `branding/` | Identity and art |
| `scripts/` | Build, test, and scan helpers |
| `docs/` | Design and release docs |

## Building (developers)

You need an Arch-based host, archiso, and the usual packaging tools. Start with
[`docs/DEVELOPING.md`](docs/DEVELOPING.md) and [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).
Do not publish an ISO until the secrets scan for that build is clean and Laden
has signed off.

```bash
# Example only — see docs for the real release path
bash packages/build-repo.sh
# ISO build is a separate, explicit release step
```

## Credits

Laden OS is based on **Arch Linux**. Some packaging and tooling history comes
from **CachyOS** and other upstreams; see [`NOTICE`](NOTICE) and [`CREDITS`](CREDITS).
Calamares, the Linux kernel, and many desktop components belong to their
upstream authors.

## Contact

Laden AS — [laden.no](https://laden.no) — admin@laden.no
