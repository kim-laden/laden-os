# Acceptance tests

Status values are Pass, Fail, or Untested. Nothing below is a Pass until `docs/TEST-REPORT.md` says so with the command that was run.

| ID | Check | How |
|---|---|---|
| A | BIOS and UEFI boot to Plasma | `scripts/test-boot.sh both ISO` |
| B | Offline boot | The QEMU test uses `-nic none` |
| C | Fresh overlay | Create `~/PROOF`, reset the VM, confirm it is gone |
| D | Persistence | Not implemented. Untested by design until it is documented and built. |
| E | SSH off | Status line `ssh=masked` and no `:22` listener |
| F | Unique boot keys | Two fingerprints in one BIOS test and one UEFI test |
| G | CockPit 1.1.0, capture off, no personal SSH targets | Not in the phase-1 image |
| H | Secret scan | `scripts/scan-secrets.py` on the unsquashed root, plus the negative fixture |
| I | Lab tools offline | Not in the phase-1 image |
| J | Calamares on an empty virtual disk | Not in the phase-1 image |
| K | Secure Boot | Unsigned. Expected Fail on a Secure Boot VM, and that result must be recorded as unsigned rather than as a supported feature. |
| L | GPU matrix | virtio in QEMU. Intel, AMD, and NVIDIA physical machines are Untested. |
| M | No Intel capture and no shipped journal | No CockPit yet. Journald is volatile. The scanner looks for host home paths. |
| N | Layout helper has no connector names | `tests/test_layout.py` |

The negative scanner fixture is `tests/fixtures/fake-key.pem`. It must fail the scan, and the report must not echo the fixture body. That test is a source test. It does not prove the ISO is clean.

Build 4 (`afd71eb1c0e43ae71de460658df54590918135e718d40bbe040f60a8b7692d23`) results, from `docs/TEST-REPORT.md`:

| ID | Result |
|---|---|
| A | Pass. BIOS and UEFI reached Plasma. The first BIOS frame was the splash; the next frame was the desktop. |
| B | Pass. The QEMU command used `-nic none`. |
| C | Pass. `proof=present`, then `proof=absent` after reset, on both firmwares. |
| E | Pass. `ssh=masked` after reset, and the listener list had no port 22. |
| F | Pass. Each firmware produced two different fingerprints. |
| H | Pass for `02e096f0…`, `3a9eb940…`, and `afd71eb1…`, with the two reviewed GnuTLS test files listed in `scripts/scan-allowlist.txt`. |
| D, G, I, J, K, L | Untested or not in this image, as the rows above say. |

The five-minute screen lock is not part of A–N. Build 3 failed it. Build 4 stayed on the BIOS desktop for 330 seconds. UEFI was not left idle.
