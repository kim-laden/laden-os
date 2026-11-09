# Package groups

`packages.x86_64` is the live desktop. `scripts/build-iso.sh` appends `lab.txt` before `mkarchiso` reads the package list.

| File | In the image | Contents |
|---|---|---|
| `lts.txt` | yes, via `packages.x86_64` | `linux-lts` is already on the default package list |
| `creator.txt` | no | FOSS creator applications |
| `gamer.txt` | no | Steam client, gamemode, mangohud, multilib Vulkan |
| `lab.txt` | yes | Most-used Kali tools, then the BlackArch forensic tools. One JDK. No catalogue group, no seclists, no Responder (it pulls MinGW) |
| `installer.txt` | no | Calamares |

Exact NVRs are recorded from the build chroot in `PACKAGES.txt`. They are not invented here.
