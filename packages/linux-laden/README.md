# linux-laden

The Laden OS kernel: the CachyOS kernel **compiled from CachyOS's own sources** under the
Laden name, so `uname -r` reads `<ver>-<rel>-laden` (e.g. `7.3.3-1-laden`).

What stays identical to CachyOS's `linux-cachyos` (x86_64_v3 repo build):

| | |
|---|---|
| sources | `CachyOS/linux` release tarball `cachyos-<ver>-<rel>` (same b2sum as upstream) + CachyOS patches |
| PKGBUILD | `CachyOS/linux-cachyos` `linux-cachyos/PKGBUILD` at `UPSTREAM_COMMIT`, run through `laden-ize.py` |
| config | `config` = the `.config` shipped in CachyOS's signed `linux-cachyos-headers` x86_64_v3 package |
| compiler | clang/LLVM ThinLTO, `-O3`, x86-64-v3, Rust enabled |
| scheduler | EEVDF + sched_ext (scx), 1000 Hz, full tickless, PREEMPT_DYNAMIC |
| modules in-tree | ntsync, v4l2loopback, etc. (provides NTSYNC-MODULE, V4L2LOOPBACK-MODULE, ...) |

What `laden-ize.py` changes (and nothing else; it fails loudly if upstream moved):
`pkgbase=linux-laden` (uname suffix `-laden`), `epoch=1`, build host `laden`, pkgdesc/url,
`GENERIC_V3` + `AUTOFDO_CLANG` as in the CachyOS binary, no `linux-cachyos-lto` provides/replaces,
`LADEN_JOBS` to cap `-j`, and a warning if the final `.config` differs from `config`.

Not reproduced: CachyOS's private AutoFDO/Propeller *profiles* (their profile server is offline),
so the code layout optimisation from profiling is not applied. Config, flags and patches are the same.

`linux-laden` no longer conflicts with `linux-cachyos`: the module dir is `/usr/lib/modules/<ver>-<rel>-laden`.
`linux-cachyos-lts` stays installed as the fallback kernel.

## Update to a new CachyOS kernel

```sh
./check-new-cachyos-kernel          # exit 10 = new CachyOS kernel available
bash update-from-cachyos.sh         # or: bash update-from-cachyos.sh <CachyOS commit>
git diff PKGBUILD config            # review
```

## Build (about 1 h on the Predator, longer when throttled)

Build outside git, e.g. `/var/tmp/laden-kernel`, as a low-priority user unit:

```sh
K=/var/tmp/laden-kernel; mkdir -p $K/{pkg,build,out,srcdest}; cp PKGBUILD config $K/pkg/
systemd-run --user --unit=laden-kernel-build -p CPUWeight=1 -p IOWeight=1 -p Nice=19 \
  -p IOSchedulingClass=idle -E LADEN_JOBS=16 \
  bash -c "cd $K/pkg && BUILDDIR=$K/build PKGDEST=$K/out SRCDEST=$K/srcdest makepkg -f --sign"
```

Pause it while gaming: `systemctl --user kill -s SIGSTOP laden-kernel-build` (resume with SIGCONT);
cap CPU when hot: `systemctl --user set-property --runtime laden-kernel-build CPUQuota=800%`.

Then: `repo-add --sign --remove laden.db.tar.zst linux-laden-*.pkg.tar.zst`, publish, snapshot,
`sudo pacman -U` both packages. DKMS (nvidia-open, xpadneo, chipsec, vmware) rebuilds for the new kver,
mkinitcpio + limine-entry-tool regenerate the initramfs and the Limine entry.

## Rollback

- Boot **Laden kernel LTS** (linux-cachyos-lts) from the Limine menu if the new kernel misbehaves.
- Reinstall the previous package: `sudo pacman -U /var/cache/pacman/pkg/linux-laden-<old>.pkg.tar.zst
  /var/cache/pacman/pkg/linux-laden-headers-<old>.pkg.tar.zst` (copies also in
  `~/.local/share/laden-backups/kernel-*/`).
- Whole system: the read-only snapshot `/.laden-snapshots/pre-linux-laden-src-*` (or a Limine *Snapshots* entry).
