# Secrets scan report (v1 prep)

Date: 2026-11-10 Europe/Oslo. Tools: gitleaks 8.30.1 (`detect --log-opts=--all`),
trufflehog git (`verified,unknown`), plus manual `rg` / `git log -S` sweeps.

## Summary

| Scanner | Result |
|---------|--------|
| gitleaks (full history, 16 commits) | 4 findings — **all false positives or intentional test fixtures** (see below) |
| trufflehog | 0 verified, 0 unverified |
| Manual | No private keys, no INetSim key, no SSH host presets, no signing **secret** key in git. Public signing key only. Host path hygiene issues remain. |

**History is not yet “scrubbed,” but no real credential that requires a history
rewrite was found.** Hygiene cleanups (absolute `/home/laden` paths, dry-run
logs) should be fixed in new commits before making the repo public. A history
rewrite is **not** required for secrets; it would only be needed if Laden
wants those paths gone from old commits too.

## gitleaks findings

| Severity | Rule | Path | Commit | Assessment |
|----------|------|------|--------|------------|
| Low (FP) | generic-api-key | `packages/linux-laden/.SRCINFO` L39–40 | a138fe8 | CachyOS **public** PGP fingerprints (`validpgpkeys`), not API secrets |
| Low (FP) | generic-api-key | `packages/linux-laden/update-from-cachyos.sh` L9 | 6b98713 | Laden repo **public** key fingerprint `BE87AF39…` |
| Info | private-key | `tests/fixtures/fake-key.pem` | c4bfcad | Intentional fake PEM for scanner unit tests (allowlisted by project design) |

## Manual findings

| Severity | What | Where | Action before public |
|----------|------|-------|----------------------|
| Medium | Absolute `/home/laden/Projects/LadenOS/...` paths | `rebrand/lib/reapply-branding`, `scripts/wallpaper/*.py`, `rebrand/DRY-RUN-SUMMARY.txt`, some docs | Replace with relative/`ROOT`-based paths; drop or regenerate dry-run summary |
| Low | `admin@laden.no`, `kim-laden@users.noreply.github.com` | PKGBUILDs, patches, metadata | Expected project contacts; OK |
| Low | Public key `packages/laden-keyring/laden.gpg` | keyring package | OK — secret key confirmed absent from tree |
| Info | Mentions of passwords / NOPASSWD in install tests | `scripts/test-installed-boot.sh`, docs | Test harness only; no live password |
| Info | `1.1.1.1` / `9.9.9.9` in `scripts/dev-vm.sh` | public DNS | OK |
| None found | INetSim private key, skel SSH config, VPS HostName presets | — | Those belong to the held Kali CockPit ISO, not this repo |
| None found | `BEGIN PGP PRIVATE`, OpenSSH private keys, `ghp_` tokens | history + tree | Clean |

## Signing key

Fingerprint `BE87AF39CC3C4610DEA910EC106B6FC0D1FF397F` (public) is referenced in
docs and scripts. Secret material lives only in `~/.gnupg` on ladenx (outside
git). Keep it that way.

## Recommendation

Safe to prepare for public **after** path hygiene commits. No git filter-repo /
BFG rewrite required for credentials based on this scan. Re-run gitleaks +
trufflehog immediately before flipping visibility.
