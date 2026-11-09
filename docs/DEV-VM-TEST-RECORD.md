# Development VM test record

Date: 2026-11-08. Host changes: none. No host packages, no USB writes, no partition or bootloader edits. The existing ISOs were not rebuilt. `scripts/release-iso.sh` was not run. The user's other VMware VMs were not powered on.

The VM is a writable installed system, not the live ISO plus a data disk. It was assembled from `build/out/laden-os-0.1.1-live-x86_64.iso` and the current profile. Root UUID `88412815-ea92-4953-bfa4-75867c18a960`. Kernel `7.2.14-arch1-1`.

## What is running

VMware Workstation, UEFI, Secure Boot off, NAT, 8 GiB RAM, 4 vCPU, 24 GiB sparse disk under `build/dev-vm/`. USB, bridged networking, shared folders, and 3D are off. The NIC is `e1000e` at PCI slot 160 behind PCIe root ports.

The first GUI power-on died before the guest started. `vmware.log` reported `msg.pci.noslotavail` for Ethernet0 and `vmware-vmx` then took signal 11. The VMX had no PCIe root ports, so Workstation pinned the NIC on a legacy slot. `scripts/dev-vm.sh` and the existing VMX now declare `pciBridge0` and `pciBridge4`–`pciBridge7`. The next start reached Plasma.

Guest address on `vmnet8`: `192.168.241.130`. SSH is the `dev` account with `build/dev-vm/keys/id_ed25519`. That key is not in `profile/`. `product.conf` still says `ssh=masked`, which is the shipping statement. The dev VM enables sshd on the NAT interface only.

The graphical seat autologins as `live`, same as the live image, so the desktop can be screenshotted. A locked test account named `fresh` is on this disk only. It is not in the profile. Autologin is `User=live`.

One snapshot exists: `after-wallpaper-sync`. VMware stored it as a sparse delta, `laden-os-dev-000002.vmdk`, parented on `laden-os-dev.vmdk` / `laden-os-dev.raw`, all inside `build/dev-vm/`.

## Wallpaper

Default file:

`/usr/share/backgrounds/laden/laden-os-lets-do-it-v2-7680x4320.png`

SHA-256 `b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f`, measured in the guest. Fill mode is PreserveAspectCrop. The other resolutions are on disk and were not selected.

`laden-os-wallpaper.service` for `live` exited 0. The marker was written only after that:

`/home/live/.config/laden-os/wallpaper-initialized`

The log line is `applied default wallpaper` at 2026-11-08T22:01:05Z. A reboot left the marker and the file in place. The service exited 0 again without treating that as a new choice.

User `fresh` was created from skel, with a locked password and no private key. After autologin, plasmashell was that user's process and the same marker was written at 22:08:27Z. `live`'s marker was unchanged. Autologin was then returned to `live` by syncing `etc/plasmalogin.conf` from the profile. No ISO was built.

Screenshots, gitignored with the rest of `build/`:

- `build/dev-vm/logs/plasma-first-boot.png`
- `build/dev-vm/logs/plasma-cockpit.png`
- `build/dev-vm/logs/plasma-after-reboot.png`
- `build/dev-vm/logs/plasma-fresh-user.png`
- `build/dev-vm/logs/plasma-after-restore.png`

The VMware window shows the v2 artwork: circuit-board "LADEN", the slogan "Let's do it!", and the top panel. The after-reboot shot also shows a KDE Wallet dialog and Chromium on `/usr/share/doc/laden-os/welcome.html`. That dialog was not on the fresh-user shot or the post-restore shot.

## Sync without an ISO

`etc/motd` in the profile gained one line naming the v2 wallpaper path. `scripts/dev-vm.sh sync --dry-run` listed `<f.st...... etc/motd` and `reboot-required=no`. The real sync wrote that line to the guest. Ownership stayed `root:root`. sshd stayed active, and the dev sudoers and ssh drop-in stayed in place. The wallpaper hash did not change.

A later sync was the thing that put `User=live` back after the fresh-user test had edited only the guest copy.

Sync does not copy host ownership. An earlier dry run would have chowned guest files to the host uid. `--no-owner --no-group` is what ran for the real sync.

## Snapshot

`scripts/dev-vm.sh snapshot` while powered on exited with "Power the VM off before snapshot." After `stop`, snapshot `after-wallpaper-sync` was created. A guest file `/etc/laden-os/snapshot-canary` was written, the VM was shut down, and `restore` of that snapshot removed the canary. The motd line, the persist token from the first boot, and `User=live` were still there. The guest booted again and SSH worked.

## Checked features

| Item | Result |
| --- | --- |
| Plasma on the installed disk | Booted. Screenshot of the v2 wallpaper. |
| Reboot persistence | Token `/etc/laden-os/dev-persist-token` survived. Wallpaper file and marker survived. |
| Fresh user | Skel default applied. No dev key in that home. |
| Profile sync | motd line arrived with no ISO and no reboot. |
| Snapshot / restore | Powered-off cycle removed a canary file. |
| The CockPit | `lcp --version` prints 1.1.0. A window titled with "Let's do it!" opened on the live seat. `/usr/bin/cockpit` is that program, not cockpit-project.org. |
| IPython | Not installed for system Python. `cockpit-ipython` exited 1 for `/usr/bin/python3` and for an empty venv, naming that interpreter. A temporary venv with IPython 9.18.1 printed `IPY_OK /tmp/ipy-yes/bin/python`. The venv was deleted. |
| Intel capture | `product.conf` has `intel_capture=off`. No capture process. `connections.lua` had no active `{` entry. |
| Lab manifests | `comm` of `packages.x86_64` plus `packages.d/lab.txt` against `pacman -Qq` was empty. `nmap`, `msfconsole`, `wireshark`, `ghidra`, `burpsuite`, and `autopsy` resolve on `PATH`. |
| Creator and gamer apps | Not installed. Checked names include `obs-studio`, `kdenlive`, `blender`, `steam`, `lutris`. |

`python3 -m unittest discover -s tests -v` — 12 tests, OK.

The CockPit 1.1.0 helper prints a `SyntaxError` on its version banner (`import sys,IPython;print(...)` quoting) and then still starts the selected interpreter. That string is in the pinned tarball, not in this profile. It was not patched.

`pacman-init.service` failed on the first boot: `pacman-key --populate archlinux` could not locally sign several keys. After the snapshot restore the unit was active. `pacman -S --needed rsync` reported the package up to date. Every such command also warned that the BlackArch database file is absent. A new BlackArch package was not installed.

Individual lab tools were not launched. Gaming, Wi-Fi, USB, and a physical GPU were not exercised. SVGA 3D is off. Launching CockPit logged Mesa/Zink device errors and the window still appeared. Those messages are not a hardware test.

## Installer, shortcuts, and the panel

Checked on the running dev VM on 2026-11-09. The guest clock still read 2026-11-08. No ISO was built. The Acer disk was not attached and was not written. The VM disk stayed writable (`lsblk` RO=0 on `sda`).

Calamares 3.4.2 is installed in this guest from the pinned tarball, with the protected-disk patch. `/usr/share/applications/calamares.desktop` is not present, so the upstream launcher cannot skip `laden-install`. `sudo -n /usr/bin/laden-install` opened a window titled "Laden OS Installer". The log said `/dev/sda holds the running system and is not an install target` and `ignored=/dev/sda`. The welcome page showed "There are no partitions to install on." The squashfs is absent on this installed disk, so the copy step cannot run here. The window was closed. No partition was created.

The Acer identity list was empty on this VM, which is the expected result while that drive is not attached. The guard's identity rules still name serial `SME8N00091140886D`, model `HFS001TEJ9X125N`, the Kingston serial and model, and the label `Acer`. Those matches are write-protected. The running-system disk is refused and is not write-protected, so the live session can keep using it.

Alt+Q is the toggle. Invoking `lcp_toggle_desktop` started `wezterm-gui` with `/usr/share/the-cockpit/config/cockpit.lua`. Invoking it again left no such process. Alt+T remains the plain `lcp` launcher.

The third panel icon is LCP. Plasma hides the pager when only one virtual desktop exists, so this seat has two desktops and the order is menu, pager, LCP. The icons-only task manager is still there for open windows, with `fill=true` and no pinned launcher. A single `org.kde.plasma.icon` applet holds the CockPit icon. The menu cache does contain `lcp.desktop`; the task manager simply did not draw that pin.

Chromium started with `laden.no` in the address bar. A KDE Wallet dialog covered the page, so the rendered site was not confirmed. `curl -I https://laden.no` returned `301` to `https://laden.no/en/`. The wallet dialog was closed with the browser. The policy file remains `/etc/chromium/policies/managed/laden-os.json`.

The Calamares build tree `/var/tmp/laden-calamares` was removed after the window check. It was 92 MiB.

## Not done

- No new ISO. `laden-os-0.1.1-live-x86_64.iso` was not live-booted in this session. Its embedded defaults are the ones from when it was built. The wallpaper fix is in the profile and on this disk.
- `scripts/release-iso.sh` was not run. The earlier lab image still fails the secret scan. Nothing was published. Secure Boot is unsigned. There is no release GPG signature.
- This VM does not prove physical GPU, gaming, Wi-Fi, or USB.
