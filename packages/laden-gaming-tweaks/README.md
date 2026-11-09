# laden-gaming-tweaks

Laden OS game mode. GameMode (`gamemoderun %command%`) calls `laden-perf-on` at game
start and `laden-perf-off` at the end.

On:
- power-profiles-daemon -> `performance` (firmware fan curve/TGP up, EPP=performance)
- sched-ext `scx_lavd --performance` via scx_loader, started by the root helper (only if no scheduler was running; no polkit prompt)
- root helper (`sudo -n /usr/lib/laden/gaming/laden-perf-helper on`, allowed for wheel):
  - hardware profile from `/usr/share/laden/gaming/hw/*.conf` (DMI match). Generic machines get no
    power-limit or clock changes.
  - Acer Predator: P-core boost cap 5.0 GHz, and `laden-perf-guard.service`, which holds an
    adaptive CPU PL1 (start 60 W, 50-75 W, PL2 90 W). It steps down 5 W when the CPU is >=92 C or the GPU is >=84 C,
    and up when the CPU is <=82 C and the GPU <=76 C. It re-applies if firmware resets RAPL, and logs to the journal every 30 s
    (package W, temps, clock, ms of thermal throttling: `journalctl -u laden-perf-guard`).
Off: everything restored from `/run/laden-perf/`.

Also: `/etc/gamemode.ini` (no Wayland-broken nvidia-settings step, no iGPU governor, no
core pinning), NVIDIA shader cache 12 GB (`/usr/lib/environment.d/60-laden-gaming.conf`),
and `/etc/xdg/plasma-workspace/env/laden-kwin-gpu.sh`: when a monitor is plugged into the
NVIDIA GPU at login, KWin renders on NVIDIA (`KWIN_DRM_DEVICES`). Turn off with
`KWIN_PRIMARY=igpu` in `/etc/laden/gaming.conf` or `touch ~/.config/laden/kwin-igpu`.

Overrides: `/etc/laden/gaming.conf`. Status: `sudo /usr/lib/laden/gaming/laden-perf-helper status`.
Already covered elsewhere (not duplicated): vm.max_map_count, split-lock, ntsync (cachyos-settings / proton).
