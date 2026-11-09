# Laden OS branding wallpapers

Ship the four v2 files under `/usr/share/backgrounds/laden/`.

| File | Size | Role | SHA-256 |
|------|------|------|---------|
| `laden-os-lets-do-it-v2-7680x4320.png` | 7680×4320 | **OS default** on every display (AI-upscaled 8K, not a native capture; Plasma scales it) | `b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f` |
| `laden-os-lets-do-it-v2-3840x2160.png` | 3840×2160 | Optional 4K override, never auto-selected | `95e751690b39febf4c1a5439b59abacf5ccc97721680bad35feacfffe3dfd184` |
| `laden-os-lets-do-it-v2-1920x1080.png` | 1920×1080 | Optional 1080p override, never auto-selected | `ea2f3ca39f9d0bda0273ef8c96a9b865dd7278e592fb69095b14060b6351b4c8` |
| `laden-os-lets-do-it-v2-3440x1440.png` | 3440×1440 | Optional ultrawide override, never auto-selected | `2b6b697de5bab6586660c88aa2e5bfb30c53027b31785a24f04c90d61155f2a9` |

Verify: `sha256sum -c SHA256SUMS-wallpapers-v2-ship.txt`

The v1 files and `laden-emerald-hp-1920x1080.png` are not the default and are not installed. Do not hardcode monitor connector names. Do not change the host desktop wallpaper from the build tree.
