# Laden OS branding wallpapers

Defaults and optional sizes under `/usr/share/backgrounds/laden/`.
Plasma package `/usr/share/wallpapers/LadenOS/` points at the **current default** (Art v5).

| Version | Role |
|---------|------|
| **v5 (Art)** | **OS default** — LADEN + deep tunnel; hidden hardware/CLI eggs; 8K set + optional 32K |
| v4 | Extra — previous calm grid-tunnel (kept installed) |
| v3 | Extra — denser neon composition (kept installed) |
| v2 | Extra — previous default (kept installed) |
| v1 | Extra — original (kept installed) |


## v5 files (Art — current default)
| File | Resolution | Role |
|------|------------|------|
| `laden-os-art-v5-7680x4320.png` | 7680×4320 | Default source for Plasma (largest non-deep) |
| `laden-os-art-v5-3840x2160.png` | 3840×2160 | 4K / SDDM |
| `laden-os-art-v5-3440x1440.png` | 3440×1440 | Ultrawide 21:9 |
| `laden-os-art-v5-2560x1440.png` | 2560×1440 | QHD |
| `laden-os-art-v5-1920x1080.png` | 1920×1080 | FHD |
| `laden-os-art-v5-deep-30720x17280.png` | 30720×17280 | Deep-zoom master |

Compatibility copies also ship as `laden-os-lets-do-it-v5-*.png`.

Verify: `sha256sum -c SHA256SUMS-wallpapers-v5-ship.txt`

## v4 files

| File | Size | Role |
|------|------|------|
| `laden-os-lets-do-it-v4-7680x4320.png` | 7680×4320 | Default source for Plasma (largest non-deep) |
| `laden-os-lets-do-it-v4-3840x2160.png` | 3840×2160 | 4K |
| `laden-os-lets-do-it-v4-3440x1440.png` | 3440×1440 | Ultrawide 21:9 (vertical center crop) |
| `laden-os-lets-do-it-v4-2560x1440.png` | 2560×1440 | QHD |
| `laden-os-lets-do-it-v4-1920x1080.png` | 1920×1080 | Splash / SDDM-friendly |
| `laden-os-lets-do-it-v4-deep-30720x17280.png` | 30720×17280 | Deep-zoom master (AI + procedural layers) |

Verify: `sha256sum -c SHA256SUMS-wallpapers-v4-ship.txt`

Do not hardcode monitor connector names.
