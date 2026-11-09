# Secrets scan report (v1 prep)

Date: 2026-11-10 Europe/Oslo. Re-run after path hygiene + public README
promotion. Tools: gitleaks 8.x (`detect --log-opts=--all` on history; exported
HEAD/working-tree scans excluding `build/` and `repo/`), trufflehog git
(`verified,unknown`).

## Summary

| Scanner | Result |
|---------|--------|
| gitleaks (full history) | 4 findings — **all false positives or intentional test fixtures** (see below) |
| gitleaks (HEAD tree export) | 3 findings — same public PGP fingerprints + `tests/fixtures/fake-key.pem` |
| gitleaks (working-tree export, pre-commit) | 3 findings — same as HEAD tree |
| trufflehog git | **0** verified, **0** unverified |
| Manual | No private keys, no INetSim key, no SSH host presets, no signing **secret** key in git. Public signing key only. Absolute `/home/laden` host paths removed from `rebrand/lib/reapply-branding`, `scripts/wallpaper/*.py`, and `rebrand/DRY-RUN-SUMMARY.txt`. |

**History is not rewritten.** No real credential requiring `git filter-repo` / BFG
was found. Remaining `/home/laden` mentions are intentional (scanner allowlists,
test harnesses that *look for* leaks, and narrative docs).

## gitleaks findings (history)

| Severity | Rule | Path | Commit | Assessment |
|----------|------|------|--------|------------|
| Low (FP) | generic-api-key | `packages/linux-laden/.SRCINFO` | a138fe8 | CachyOS **public** PGP fingerprints (`validpgpkeys`) |
| Low (FP) | generic-api-key | `packages/linux-laden/update-from-cachyos.sh` | 6b98713 | Laden repo **public** key fingerprint `BE87AF39…` |
| Info | private-key | `tests/fixtures/fake-key.pem` | c4bfcad | Intentional fake PEM for scanner unit tests |

## Hygiene fixed this pass

| Item | Action |
|------|--------|
| `rebrand/lib/reapply-branding` | Repo-relative / `/usr/share/laden` fallbacks; no `/home/laden/...` |
| `scripts/wallpaper/build_v4_deep.py`, `build_v5_art_deep.py`, `v5_redraw_hardware_cli.py` | `_REPO = Path(__file__).resolve().parents[2]` |
| `rebrand/DRY-RUN-SUMMARY.txt` | Host paths removed; placeholder note only |

## Signing key

Fingerprint `BE87AF39CC3C4610DEA910EC106B6FC0D1FF397F` (public) is referenced in
docs and scripts. Secret material lives only in `~/.gnupg` on ladenx (outside
git). Keep it that way.

## Recommendation

Safe to flip the GitHub repository to **public** after this commit is pushed.
Laden flips visibility; do not automate that. Re-run gitleaks + trufflehog on
any ISO rootfs before publishing a download.
