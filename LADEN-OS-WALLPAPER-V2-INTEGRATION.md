# Laden OS — wallpaper v2 integration (for Grok Build)

Owner-approved: once the current build finishes, **v2 ships with the OS**. v2 8K is the default on every display (scaled down); 4K/1080p/ultrawide are optional user overrides; ultrawide is never auto-selected. 8K is AI-upscaled, not native. HP emerald is reference only.

## Pins
- v2-7680x4320 (DEFAULT) b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f
- v2-3840x2160 95e751690b39febf4c1a5439b59abacf5ccc97721680bad35feacfffe3dfd184
- v2-1920x1080 ea2f3ca39f9d0bda0273ef8c96a9b865dd7278e592fb69095b14060b6351b4c8
- v2-3440x1440 2b6b697de5bab6586660c88aa2e5bfb30c53027b31785a24f04c90d61155f2a9

## Rules
1. Do NOT touch the running build, its work dir, or a finished ISO in place. Let it finish; treat its output as a v1-wallpaper candidate.
2. Editing the profile (`airootfs/…`) does NOT change a build already running: mkarchiso copied airootfs into its work root at start.
3. A finished ISO is read-only. Changing a file means: extract squashfs → replace file → re-squash (same compression as profile) → repack ISO keeping BIOS/UEFI boot structures → regenerate checksums/signatures → boot-test BIOS+UEFI. This can skip re-downloading packages but is still a new artifact; a clean `mkarchiso` rebuild from the updated profile is the preferred, reproducible path.

## Option A — canonical (preferred)
- Copy the 4 v2 files to `airootfs/usr/share/backgrounds/laden/` (`sha256sum -c` first, mode 0644).
- Point the Plasma default to `/usr/share/backgrounds/laden/laden-os-lets-do-it-v2-7680x4320.png` everywhere the old path appears (grep the profile for `lets-do-it` / `backgrounds/laden`: e.g. look-and-feel/wallpaper defaults, `/etc/skel` plasma config, greeter theme).
- Rebuild clean with mkarchiso into a fresh work dir; record new ISO SHA256 + PACKAGES.

## Option B — drop-in (only if config references the v1 filename and you want zero config edits)
- Install v2 8K bytes at the existing v1 path `laden-os-lets-do-it-7680x4320.png` (and same for the other sizes), and record in the manifest/SBOM: "file name v1, content = v2, sha256 b0abe88e…". Canonical v2 filenames may ship alongside.
- Then still rebuild (or repack per rule 3). Prefer Option A for clarity.

## Acceptance
- `sha256sum` of installed files in the extracted squashfs matches pins.
- Fresh live boot shows v2 on every connected display (record resolutions tested).
- No connector names hardcoded; user overrides preserved.
- Old ISO kept as-is for comparison; new ISO gets new checksums.
