#!/bin/bash
# SPDX-License-Identifier: MIT
# Persistent Laden OS development VM (VMware Workstation, NAT, UEFI).
# Disks, firmware variables, keys, and logs stay under build/dev-vm/.
# This does not write a physical disk, a USB device, or an ISO.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VM=$ROOT/build/dev-vm
VMX=$VM/laden-os-dev.vmx
RAW=$VM/laden-os-dev.raw
DISK=$VM/laden-os-dev.vmdk
KEYDIR=$VM/keys
KEY=$KEYDIR/id_ed25519
ISO=$ROOT/build/out/laden-os-0.1.1-live-x86_64.iso
ISO_SUM=$ROOT/build/out/SHA256SUMS-laden-os-0.1.1-live-x86_64
PROFILE=$ROOT/profile/laden-os
WALL_SUM=$ROOT/branding/SHA256SUMS-wallpapers-v2-ship.txt
WALL_HASH=b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f
UNSQUASH=$ROOT/build/host-tools/usr/bin/unsquashfs
LOGDIR=$VM/logs

usage() {
    cat <<EOF
usage: scripts/dev-vm.sh COMMAND

  create              Build the UEFI disk from the 0.1.1 squashfs plus the
                      current profile. Refuses to replace an existing disk.
  start               Start the VM in the VMware GUI (NAT, no USB).
  stop                ACPI shutdown. Refuses a hard power-off.
  status              Power state, snapshots, and guest address when known.
  snapshot NAME       Snapshot while powered off.
  restore NAME        Restore a snapshot while powered off.
  sync [--dry-run]    Copy project-managed files into the running guest.
  ssh -- COMMAND      Run a command as the dev user over the dev key.
  files               Print the managed file set. Does not touch the guest.

ISO builds stay in scripts/release-iso.sh. create does not publish anything.
EOF
}

log() {
    printf '%s %s\n' "$(date -Is)" "$*" | tee -a "$LOGDIR/dev-vm.log" >&2
}

refuse_host_device() {
    local path=$1
    case "$path" in
        /dev|/*/dev/*)
            echo "refusing a host device path: $path" >&2
            exit 2
            ;;
    esac
    if [[ -b $path || -c $path ]]; then
        echo "refusing a block or character device: $path" >&2
        exit 2
    fi
}

vm_running() {
    vmrun -T ws list 2>/dev/null | grep -F "$VMX" >/dev/null
}

require_disk() {
    if [[ ! -f $VMX || ! -f $DISK || ! -f $RAW ]]; then
        echo "The development VM does not exist. Run: scripts/dev-vm.sh create" >&2
        exit 2
    fi
    refuse_host_device "$VMX"
    refuse_host_device "$DISK"
    refuse_host_device "$RAW"
}

assert_vmx_safe() {
    local hit
    hit=$(grep -E '^[^#]*(fileName|deviceName) *= *"/dev/|connectionType *= *"bridged"|usb.present *= *"TRUE"|ehci.present *= *"TRUE"|usb_xhci.present *= *"TRUE"' "$VMX" || true)
    if [[ -n $hit ]]; then
        echo "Refusing to start. The VMX names a physical disk, bridged NIC, or USB controller:" >&2
        printf '%s\n' "$hit" >&2
        exit 2
    fi
}

guest_mac() {
    awk -F '"' '/ethernet0.generatedAddress *=/ { print $2; exit }' "$VMX"
}

guest_ip() {
    local ip mac leases block
    if vm_running; then
        ip=$(timeout 8 vmrun -T ws getGuestIPAddress "$VMX" 2>/dev/null || true)
        if [[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ && $ip != 0.0.0.0 ]]; then
            printf '%s\n' "$ip"
            return 0
        fi
    fi
    mac=$(guest_mac || true)
    leases=/etc/vmware/vmnet8/dhcpd/dhcpd.leases
    if [[ -n ${mac:-} && -r $leases ]]; then
        ip=$(awk -v mac="$mac" '
            $1 == "lease" { cur = $2 }
            $1 == "hardware" && $2 == "ethernet" && tolower($3) == tolower(mac ";") { found = cur }
            END { if (found) print found }
        ' "$leases")
        if [[ -n ${ip:-} ]]; then
            printf '%s\n' "$ip"
            return 0
        fi
    fi
    return 1
}

ssh_base() {
    local ip=$1
    shift
    ssh -i "$KEY" \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile="$KEYDIR/known_hosts" \
        -o PasswordAuthentication=no \
        -o ConnectTimeout=8 \
        -o BatchMode=yes \
        "dev@$ip" "$@"
}

check_rel_path() {
    local path=$1
    if [[ -z $path || $path == /* || $path == *..* ]]; then
        echo "refusing unmanaged path: ${path:-<empty>}" >&2
        return 1
    fi
    return 0
}

build_sync_tree() {
    local dest=$1
    rm -rf "$dest"
    mkdir -p "$dest"
    rsync -a \
        --exclude-from="$PROFILE/dev-vm-sync-exclude.txt" \
        "$PROFILE/airootfs/" "$dest/"
    local wall=$dest/usr/share/backgrounds/laden
    mkdir -p "$wall"
    rm -f "$wall"/laden-os-lets-do-it-*.png "$wall"/*emerald* "$wall"/*hp*
    while read -r _sum file; do
        [[ -n ${file:-} ]] || continue
        cp -a "$ROOT/branding/$file" "$wall/"
    done <"$WALL_SUM"
    rm -f \
        "$dest/etc/systemd/system/sshd.service" \
        "$dest/etc/systemd/system/sshd.socket" \
        "$dest/etc/mkinitcpio.conf.d/archiso.conf"
    local got
    got=$(sha256sum "$wall/laden-os-lets-do-it-v2-7680x4320.png" | awk '{print $1}')
    if [[ $got != "$WALL_HASH" ]]; then
        echo "sync tree wallpaper hash mismatch" >&2
        exit 2
    fi
    if grep -R -l -E 'BEGIN OPENSSH PRIVATE KEY|BEGIN PRIVATE KEY' "$dest" >/dev/null 2>&1; then
        echo "sync tree contains a private key" >&2
        exit 2
    fi
    if [[ -e $dest/etc/sudoers.d/10-laden-dev || -e $dest/home/laden ]]; then
        echo "sync tree contains development access or a host home" >&2
        exit 2
    fi
    local rel
    while IFS= read -r rel; do
        [[ -n $rel ]] || continue
        check_rel_path "$rel" || exit 2
    done < <(cd "$dest" && find . -mindepth 1 -printf '%P\n')
}

owned_dirs() {
    awk '
        /^[[:space:]]*($|#)/ { next }
        { print }
    ' "$PROFILE/dev-vm-sync-owned.txt"
}

cmd_files() {
    local dest count
    dest=$(mktemp -d "${TMPDIR:-/tmp}/laden-sync.XXXX")
    build_sync_tree "$dest"
    count=$(find "$dest" -mindepth 1 | wc -l)
    printf 'managed-paths=%s\n' "$count"
    printf 'wallpaper=%s\n' "$WALL_HASH"
    echo "excluded:"
    grep -E '^[^#[:space:]]' "$PROFILE/dev-vm-sync-exclude.txt"
    echo "delete-only-inside:"
    owned_dirs
    rm -rf "$dest"
}

write_vmx() {
    mkdir -p "$LOGDIR"
    cat >"$VMX" <<EOF
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "21"
displayName = "Laden OS dev"
guestOS = "other6xlinux-64"
firmware = "efi"
uefi.secureBoot.enabled = "FALSE"
memsize = "8192"
numvcpus = "4"
cpuid.coresPerSocket = "2"
vhv.enable = "FALSE"
# e1000e is PCIe. Without these root ports Workstation pins the NIC on a
# legacy slot, reports "No PCIe slot available", and the VMX process crashes.
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
vmci0.present = "TRUE"

sata0.present = "TRUE"
sata0:0.present = "TRUE"
sata0:0.fileName = "laden-os-dev.vmdk"
sata0:0.deviceType = "disk"

sata0:1.present = "FALSE"
ide0:0.present = "FALSE"
ide1:0.present = "FALSE"
floppy0.present = "FALSE"
usb.present = "FALSE"
ehci.present = "FALSE"
usb_xhci.present = "FALSE"
usb.generic.autoconnect = "FALSE"

ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "e1000e"
ethernet0.addressType = "generated"
ethernet0.wakeOnPcktRcv = "FALSE"

sound.present = "FALSE"
svga.vramSize = "134217728"
mks.enable3d = "FALSE"
RemoteDisplay.vnc.enabled = "FALSE"

serial0.present = "TRUE"
serial0.fileType = "file"
serial0.fileName = "logs/serial.log"
serial0.startConnected = "TRUE"

isolation.tools.hgfs.disable = "TRUE"
sharedFolder.maxNum = "0"
isolation.tools.dnd.disable = "TRUE"
hgfs.linkRootShare = "FALSE"

tools.syncTime = "TRUE"
tools.remindInstall = "FALSE"
uuid.action = "create"
msg.autoAnswer = "TRUE"
nvram = "laden-os-dev.nvram"
extendedConfigFile = "laden-os-dev.vmxf"
workingDir = "."
EOF
    assert_vmx_safe
}

cmd_create() {
    if [[ ${LADEN_DEV_VM_INNER:-0} != 1 ]]; then
        if [[ -n ${SUDO_UID:-} || $(id -u) -eq 0 ]]; then
            echo "Refusing to run create through sudo or as the host root user." >&2
            exit 2
        fi
        export LADEN_DEV_VM_INNER=1
        # --pid is required on this kernel. A user namespace may mount proc
        # only inside a PID namespace it owns. --fork keeps the launcher alive
        # until the inner script exits.
        exec unshare --fork --pid --mount --map-auto --map-root-user --setuid 0 --setgid 0 -- "$ROOT/scripts/dev-vm.sh" create
    fi

    mkdir -p "$LOGDIR"
    : >"$LOGDIR/create.log"
    exec > >(tee -a "$LOGDIR/create.log") 2>&1
    trap 'echo "create failed at line $LINENO"' ERR
    log "create starting"

    if [[ -e $RAW || -e $DISK || -e $VMX ]]; then
        echo "Refusing to replace an existing development VM disk." >&2
        echo "Existing files under $VM were left untouched." >&2
        exit 2
    fi
    refuse_host_device "$RAW"
    refuse_host_device "$ISO"
    if [[ ! -f $ISO ]]; then
        echo "Missing source ISO: $ISO" >&2
        exit 2
    fi
    if [[ ! -x $UNSQUASH ]]; then
        echo "unsquashfs is missing at $UNSQUASH" >&2
        exit 2
    fi
    local avail_kb mem_kb
    avail_kb=$(df -Pk "$ROOT" | awk 'NR==2 { print $4 }')
    if (( avail_kb < 30 * 1024 * 1024 )); then
        echo "Need at least 30 GiB free for the VM disk. Have ${avail_kb} KiB." >&2
        echo "ISOs under build/out were not removed." >&2
        exit 2
    fi
    mem_kb=$(awk '/MemAvailable/ { print $2 }' /proc/meminfo)
    if (( mem_kb < 10 * 1024 * 1024 )); then
        echo "Need at least 10 GiB available RAM before an 8 GiB guest. Have ${mem_kb} KiB." >&2
        exit 2
    fi
    if ! command -v vmrun >/dev/null || ! command -v vmware-vdiskmanager >/dev/null; then
        echo "VMware Workstation commands are not installed." >&2
        exit 2
    fi

    local expected got
    expected=$(awk 'NR==1 { print $1 }' "$ISO_SUM")
    log "hashing source ISO"
    got=$(sha256sum "$ISO" | awk '{ print $1 }')
    if [[ $got != "$expected" ]]; then
        echo "Source ISO hash does not match $ISO_SUM" >&2
        exit 2
    fi
    log "source ISO hash ok"

    mkdir -p "$KEYDIR" "$VM/staging"
    if [[ ! -f $KEY ]]; then
        ssh-keygen -t ed25519 -N '' -C 'laden-os-dev-vm' -f "$KEY"
        chmod 600 "$KEY"
    fi

    local rootfs=$VM/staging/root
    local synctree=$VM/staging/sync-src
    if [[ -f $rootfs/etc/os-release && ! -e $VM/staging/airootfs.sfs ]]; then
        log "reusing the extracted root"
    else
        rm -rf "$rootfs" "$synctree"
        mkdir -p "$VM/staging"
        log "extracting airootfs"
        xorriso -osirrox on -indev "$ISO" \
            -extract /laden/x86_64/airootfs.sfs "$VM/staging/airootfs.sfs"
        if ! "$UNSQUASH" -d "$rootfs" "$VM/staging/airootfs.sfs"; then
            log "unsquashfs retry without xattrs"
            rm -rf "$rootfs"
            "$UNSQUASH" -d "$rootfs" -no-xattrs "$VM/staging/airootfs.sfs"
        fi
        rm -f "$VM/staging/airootfs.sfs"
        log "squashfs extracted"
    fi

    if [[ -d $rootfs/home/laden ]]; then
        rm -rf "$rootfs/home/laden"
        log "removed leaked /home/laden from the VM root"
    fi

    log "overlaying the current profile"
    build_sync_tree "$synctree"
    rsync -a "$synctree/" "$rootfs/"
    rm -f \
        "$rootfs/etc/systemd/system/sshd.service" \
        "$rootfs/etc/systemd/system/sshd.socket" \
        "$rootfs/etc/mkinitcpio.conf.d/archiso.conf"
    local wall=$rootfs/usr/share/backgrounds/laden
    rm -f "$wall"/laden-os-lets-do-it-*.png "$wall"/*emerald* "$wall"/*hp*
    cp -a "$synctree/usr/share/backgrounds/laden/." "$wall/"

    local live_rc=$rootfs/home/live/.config/plasma-org.kde.plasma.desktop-appletsrc
    if [[ -f $live_rc ]] && grep -q 'laden-os-lets-do-it-7680x4320.png' "$live_rc"; then
        sed -i 's|laden-os-lets-do-it-7680x4320.png|laden-os-lets-do-it-v2-7680x4320.png|g' "$live_rc"
        log "rewrote the live user's v1 wallpaper path"
    fi

    printf 'uninitialized\n' >"$rootfs/etc/machine-id"
    printf 'laden-os-dev\n' >"$rootfs/etc/hostname"
    if ! grep -q 'laden-os-dev' "$rootfs/etc/hosts"; then
        printf '127.0.0.1 localhost laden-os-dev\n::1 localhost laden-os-dev\n' >>"$rootfs/etc/hosts"
    fi

    cat >"$rootfs/etc/mkinitcpio.conf.d/laden-installed.conf" <<'EOF'
# Installed development disk. This file is not part of the live ISO profile.
# The archiso hook and the broad live MODULES list stay out of this image.
MODULES=(ext4 vfat sd_mod ahci libahci ata_piix virtio_pci virtio_blk virtio_scsi nvme vmw_pvscsi mptspi)
HOOKS=(base udev microcode modconf filesystems keyboard fsck)
COMPRESSION="zstd"
COMPRESSION_OPTIONS=(-6)
EOF
    printf '%s\n' '# Development VM only. Not part of the live ISO.' \
        'role=development' >"$rootfs/etc/laden-os/dev-vm.conf"

    provision_packages "$rootfs"
    provision_access "$rootfs"
    provision_boot "$rootfs"
    assemble_disk "$rootfs"
    write_vmx

    rm -rf "$VM/staging"
    log "create finished"
    printf 'VMX=%s\n' "$VMX"
    printf 'Next: scripts/dev-vm.sh start\n'
}

chroot_do() {
    local rootfs=$1
    shift
    chroot "$rootfs" /usr/bin/env HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin "$@"
}

mount_chroot() {
    local rootfs=$1 node
    mkdir -p "$rootfs/proc" "$rootfs/sys" "$rootfs/dev/pts" "$rootfs/run" "$rootfs/var/cache/pacman/pkg"
    # Bind the root onto itself first. mkinitcpio treats /dev as unmounted
    # unless the chroot directory is a mountpoint and /dev is mounted under it.
    if ! mountpoint -q "$rootfs"; then
        mount --bind "$rootfs" "$rootfs"
    fi
    mount -t proc proc -o nosuid,noexec,nodev "$rootfs/proc"
    # A fresh sysfs mount is rejected in this user namespace. Bind the host
    # sysfs as a slave so unmounting it does not affect the host.
    mount --rbind /sys "$rootfs/sys"
    mount --make-rslave "$rootfs/sys"
    mount -t tmpfs -o mode=0755,nosuid tmpfs "$rootfs/dev"
    mkdir -p "$rootfs/dev/pts" "$rootfs/dev/shm"
    ln -sfn /proc/self/fd "$rootfs/dev/fd"
    ln -sfn /proc/self/fd/0 "$rootfs/dev/stdin"
    ln -sfn /proc/self/fd/1 "$rootfs/dev/stdout"
    ln -sfn /proc/self/fd/2 "$rootfs/dev/stderr"
    for node in null zero random urandom full tty console; do
        if [[ -e /dev/$node ]]; then
            touch "$rootfs/dev/$node"
            mount --bind "/dev/$node" "$rootfs/dev/$node"
        fi
    done
    mount -t devpts devpts "$rootfs/dev/pts" || true
    mount -t tmpfs -o mode=0755,nosuid,nodev tmpfs "$rootfs/run"
    mount --bind "$ROOT/build/pacman-cache" "$rootfs/var/cache/pacman/pkg"
}

umount_chroot() {
    local rootfs=$1
    local mountpoint
    for mountpoint in \
        "$rootfs/var/cache/pacman/pkg" \
        "$rootfs/dev/pts" \
        "$rootfs/dev/console" \
        "$rootfs/dev/tty" \
        "$rootfs/dev/full" \
        "$rootfs/dev/urandom" \
        "$rootfs/dev/random" \
        "$rootfs/dev/zero" \
        "$rootfs/dev/null" \
        "$rootfs/dev" \
        "$rootfs/run" \
        "$rootfs/sys" \
        "$rootfs/proc" \
        "$rootfs"
    do
        if mountpoint -q "$mountpoint"; then
            umount "$mountpoint" 2>/dev/null || umount -l "$mountpoint" || true
        fi
    done
}

provision_packages() {
    local rootfs=$1
    local resolv_link=/run/systemd/resolve/stub-resolv.conf
    if [[ -L $rootfs/etc/resolv.conf ]]; then
        resolv_link=$(readlink "$rootfs/etc/resolv.conf")
    fi
    rm -f "$rootfs/etc/resolv.conf"
    if [[ -f /run/systemd/resolve/resolv.conf ]]; then
        cp -a /run/systemd/resolve/resolv.conf "$rootfs/etc/resolv.conf"
    else
        printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' >"$rootfs/etc/resolv.conf"
    fi

    mount_chroot "$rootfs"
    log "populating the guest pacman keyring"
    chroot_do "$rootfs" pacman-key --init
    chroot_do "$rootfs" pacman-key --populate archlinux
    chroot_do "$rootfs" pacman-key --populate blackarch || log "blackarch key populate returned non-zero"
    awk '
        /^\[blackarch\]/ { skip = 1 }
        skip { next }
        { print }
    ' "$rootfs/etc/pacman.conf" >"$rootfs/etc/pacman.conf.laden-dev-install"
    log "installing development-only packages"
    if ! chroot_do "$rootfs" pacman --config /etc/pacman.conf.laden-dev-install -Sy --noconfirm --disable-sandbox --needed openssh open-vm-tools rsync; then
        chroot_do "$rootfs" pacman --config /etc/pacman.conf.laden-dev-install -Sy --noconfirm --needed openssh open-vm-tools rsync
    fi
    rm -f "$rootfs/etc/pacman.conf.laden-dev-install"
    umount_chroot "$rootfs"
    if [[ -n $resolv_link ]]; then
        rm -f "$rootfs/etc/resolv.conf"
        ln -s "$resolv_link" "$rootfs/etc/resolv.conf"
    fi
    if [[ ! -x $rootfs/usr/bin/sshd || ! -x $rootfs/usr/bin/vmtoolsd || ! -x $rootfs/usr/bin/rsync ]]; then
        echo "Development packages did not install into the guest root." >&2
        exit 1
    fi
}

provision_access() {
    local rootfs=$1
    mount_chroot "$rootfs"
    if ! chroot_do "$rootfs" id dev >/dev/null 2>&1; then
        chroot_do "$rootfs" useradd -m -G wheel -s /bin/bash -c "Laden OS development access" dev
    fi
    chroot_do "$rootfs" passwd -l dev
    chroot_do "$rootfs" install -d -m 0700 -o dev -g dev /home/dev/.ssh
    install -m 0600 "$KEY.pub" "$rootfs/home/dev/.ssh/authorized_keys"
    chroot_do "$rootfs" chown dev:dev /home/dev/.ssh/authorized_keys
    printf 'dev ALL=(ALL:ALL) NOPASSWD: ALL\n' >"$rootfs/etc/sudoers.d/10-laden-dev"
    chmod 0440 "$rootfs/etc/sudoers.d/10-laden-dev"
    chroot_do "$rootfs" visudo -cf /etc/sudoers.d/10-laden-dev
    mkdir -p "$rootfs/etc/ssh/sshd_config.d"
    cat >"$rootfs/etc/ssh/sshd_config.d/99-laden-dev.conf" <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
AllowUsers dev
EOF
    rm -f "$rootfs/etc/ssh/ssh_host_"*
    local unit
    mkdir -p "$rootfs/etc/systemd/system/multi-user.target.wants"
    for unit in sshd.service vmtoolsd.service; do
        if [[ ! -e $rootfs/usr/lib/systemd/system/$unit ]]; then
            echo "Missing unit after package install: $unit" >&2
            umount_chroot "$rootfs"
            exit 1
        fi
        ln -sfn "/usr/lib/systemd/system/$unit" \
            "$rootfs/etc/systemd/system/multi-user.target.wants/$unit"
    done
    umount_chroot "$rootfs"
}

provision_boot() {
    local rootfs=$1
    local kver="" base dir
    for dir in "$rootfs"/usr/lib/modules/*; do
        [[ -d $dir ]] || continue
        base=$(basename "$dir")
        if [[ -f $dir/pkgbase && $(<"$dir/pkgbase") == linux ]]; then
            kver=$base
        fi
    done
    if [[ -z $kver ]]; then
        echo "Could not find the default linux module directory." >&2
        exit 1
    fi
    mkdir -p "$rootfs/boot"
    if [[ ! -f $rootfs/boot/vmlinuz-linux ]]; then
        log "copying vmlinuz from the ISO"
        xorriso -osirrox on -indev "$ISO" \
            -extract /laden/boot/x86_64/vmlinuz-linux "$rootfs/boot/vmlinuz-linux"
    fi
    log "building the installed initramfs for $kver"
    mount_chroot "$rootfs"
    chroot_do "$rootfs" mkinitcpio -k "$kver" -g /boot/initramfs-linux.img
    umount_chroot "$rootfs"
    if [[ ! -s $rootfs/boot/initramfs-linux.img ]]; then
        echo "mkinitcpio did not write an initramfs." >&2
        exit 1
    fi
    log "initramfs bytes $(stat -c %s "$rootfs/boot/initramfs-linux.img")"
}

assemble_disk() {
    local rootfs=$1
    local raw=$VM/staging/disk.raw
    local esp=$VM/staging/esp.img
    local rootimg=$VM/staging/root.img
    local descriptor=$VM/staging/laden-os-dev.vmdk
    local root_uuid esp_id
    root_uuid=$(uuidgen)
    # 24 GiB leaves room for the installed lab root (about 12 GiB) plus
    # later package tests. The file stays sparse on the host.
    truncate -s 24G "$raw"
    parted -s "$raw" mklabel gpt
    parted -s "$raw" mkpart ESP fat32 1MiB 513MiB
    parted -s "$raw" set 1 esp on
    parted -s "$raw" name 1 laden-esp
    parted -s "$raw" mkpart root ext4 513MiB 100%
    parted -s "$raw" name 2 laden-root

    local esp_start esp_size root_start root_size
    # shellcheck disable=SC2046
    read -r esp_start esp_size root_start root_size < <(parted -m -s "$raw" unit B print | awk -F: '
        $1 == "1" { esp_start = $2; esp_size = $4 }
        $1 == "2" { root_start = $2; root_size = $4 }
        END { gsub(/B/, "", esp_start); gsub(/B/, "", esp_size); gsub(/B/, "", root_start); gsub(/B/, "", root_size); print esp_start, esp_size, root_start, root_size }
    ')
    log "ESP start=$esp_start size=$esp_size root start=$root_start size=$root_size"
    truncate -s "$esp_size" "$esp"
    mkfs.fat -F 32 -n LADENESP "$esp"
    esp_id=$(blkid -s UUID -o value "$esp")
    if [[ -z $esp_id ]]; then
        echo "ESP filesystem has no UUID." >&2
        exit 1
    fi
    cat >"$rootfs/etc/fstab" <<EOF
UUID=$root_uuid / ext4 rw,relatime 0 1
UUID=$esp_id /boot vfat rw,relatime,fmask=0133,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 2
EOF
    printf 'root=%s\nesp=%s\n' "$root_uuid" "$esp_id" >"$VM/disk-uuid"

    local bootefi=$rootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi
    if [[ ! -f $bootefi ]]; then
        echo "systemd-boot EFI binary is missing from the root." >&2
        exit 1
    fi
    mmd -i "$esp" ::/EFI
    mmd -i "$esp" ::/EFI/BOOT
    mmd -i "$esp" ::/EFI/systemd
    mmd -i "$esp" ::/loader
    mmd -i "$esp" ::/loader/entries
    mcopy -i "$esp" "$bootefi" ::/EFI/BOOT/BOOTX64.EFI
    mcopy -i "$esp" "$bootefi" ::/EFI/systemd/systemd-bootx64.efi
    mcopy -i "$esp" "$rootfs/boot/vmlinuz-linux" ::/vmlinuz-linux
    mcopy -i "$esp" "$rootfs/boot/initramfs-linux.img" ::/initramfs-linux.img
    printf '%s\n' 'default laden.conf' 'timeout 3' 'console-mode keep' 'editor no' \
        >"$VM/staging/loader.conf"
    cat >"$VM/staging/laden.conf" <<EOF
title    Laden OS
linux    /vmlinuz-linux
initrd   /initramfs-linux.img
options  root=UUID=$root_uuid rw rootfstype=ext4 console=tty0 console=ttyS0,115200
EOF
    mcopy -i "$esp" "$VM/staging/loader.conf" ::/loader/loader.conf
    mcopy -i "$esp" "$VM/staging/laden.conf" ::/loader/entries/laden.conf

    if (( esp_start % 1048576 != 0 || root_start % 1048576 != 0 )); then
        echo "Partition start is not 1 MiB aligned." >&2
        exit 1
    fi
    if findmnt -R "$rootfs" >/dev/null 2>&1; then
        echo "Refusing to image a root that still has mounts." >&2
        findmnt -R "$rootfs" >&2 || true
        exit 1
    fi
    log "writing the ext4 root image"
    truncate -s "$root_size" "$rootimg"
    mkfs.ext4 -F -L laden-root -U "$root_uuid" -d "$rootfs" -m 1 "$rootimg"
    log "removing the unpacked root now that the ext4 image has it"
    rm -rf "$rootfs"
    log "copying filesystems into the disk image"
    dd if="$esp" of="$raw" bs=1M seek=$((esp_start / 1048576)) conv=sparse,notrunc status=progress
    dd if="$rootimg" of="$raw" bs=1M seek=$((root_start / 1048576)) conv=sparse,notrunc status=progress
    rm -f "$esp" "$rootimg"

    local sectors cid cyl
    sectors=$(( $(stat -c %s "$raw") / 512 ))
    cid=$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')
    cyl=$(( sectors / (255 * 63) ))
    if (( cyl < 1 )); then
        cyl=1
    fi
    cat >"$descriptor" <<EOF
# Disk DescriptorFile
version=1
encoding="UTF-8"
CID=$cid
parentCID=ffffffff
createType="monolithicFlat"
# Extent description
RW $sectors FLAT "laden-os-dev.raw" 0

# The Disk Data Base
ddb.adapterType = "lsilogic"
ddb.geometry.cylinders = "$cyl"
ddb.geometry.heads = "255"
ddb.geometry.sectors = "63"
ddb.virtualHWVersion = "21"
EOF
    mv "$raw" "$RAW"
    mv "$descriptor" "$DISK"
    log "disk descriptor written ($sectors sectors)"
}

cmd_start() {
    require_disk
    assert_vmx_safe
    if vm_running; then
        echo "already running"
        exit 0
    fi
    export DISPLAY=${DISPLAY:-:0}
    if [[ -z ${XDG_RUNTIME_DIR:-} && -d /run/user/$(id -u) ]]; then
        export XDG_RUNTIME_DIR=/run/user/$(id -u)
    fi
    if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} && -S ${XDG_RUNTIME_DIR:-}/bus ]]; then
        export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
    fi
    # Workstation's GTK UI is an X11 client. On a Wayland session it needs the
    # session bus and the X display, or vmrun waits forever with no window.
    export GDK_BACKEND=${GDK_BACKEND:-x11}
    # A crashed power-on leaves a disk lock. Remove it only when this VM is
    # not running. Never delete a lock that a live vmware-vmx still holds.
    if ! pgrep -f "vmware-vmx.*${VMX}" >/dev/null 2>&1; then
        rm -rf "$VM/laden-os-dev.vmdk.lck"
    fi
    vmrun -T ws start "$VMX" gui
}

cmd_stop() {
    require_disk
    if ! vm_running; then
        echo "already stopped"
        exit 0
    fi
    vmrun -T ws stop "$VMX" soft
    local _try
    for _try in $(seq 1 60); do
        if ! vm_running; then
            echo "stopped"
            exit 0
        fi
        sleep 2
    done
    echo "The guest did not power off within 120 seconds. It was left running." >&2
    exit 1
}

snapshot_name_ok() {
    local name=$1
    [[ $name =~ ^[A-Za-z0-9._-]+$ ]]
}

cmd_snapshot() {
    local name=${1:-}
    require_disk
    if [[ -z $name ]] || ! snapshot_name_ok "$name"; then
        echo "usage: scripts/dev-vm.sh snapshot NAME" >&2
        exit 2
    fi
    if vm_running; then
        echo "Power the VM off before snapshot. Live snapshots are not implemented." >&2
        exit 2
    fi
    vmrun -T ws snapshot "$VMX" "$name"
}

cmd_restore() {
    local name=${1:-}
    require_disk
    if [[ -z $name ]] || ! snapshot_name_ok "$name"; then
        echo "usage: scripts/dev-vm.sh restore NAME" >&2
        exit 2
    fi
    if vm_running; then
        echo "Power the VM off before restore. Live restore is not implemented." >&2
        exit 2
    fi
    vmrun -T ws revertToSnapshot "$VMX" "$name"
}

cmd_status() {
    if [[ -f $VMX ]]; then
        if vm_running; then
            echo "power=on"
        else
            echo "power=off"
        fi
        vmrun -T ws listSnapshots "$VMX" || true
        if ip=$(guest_ip); then
            echo "guest_ip=$ip"
        else
            echo "guest_ip=unknown"
        fi
    else
        echo "power=absent"
    fi
    if [[ -f $RAW ]]; then
        echo "raw_bytes=$(stat -c %s "$RAW")"
        echo "raw_allocated=$(du -B1 "$RAW" | awk '{print $1}')"
    fi
}

reboot_reason() {
    local line path kind
    while IFS= read -r line; do
        # rsync -i: a leading "." is metadata only. Do not reboot for that.
        kind=${line%% *}
        [[ $kind == \<* || $kind == \>* || $kind == c* || $kind == h* ]] || continue
        [[ $kind == ?f* || $kind == ?L* ]] || continue
        path=${line#* }
        path=${path#/}
        case "$path" in
            boot/*|usr/lib/modules/*|usr/lib/systemd/system/*|etc/mkinitcpio.conf|etc/mkinitcpio.conf.d/*)
                printf '%s\n' "$path"
                ;;
        esac
    done
}

cmd_sync() {
    local dry=0
    if [[ ${1:-} == --dry-run ]]; then
        dry=1
    elif [[ -n ${1:-} ]]; then
        echo "usage: scripts/dev-vm.sh sync [--dry-run]" >&2
        exit 2
    fi
    require_disk
    local stamp dest ip rsh log owned dir
    stamp=$(date +%Y%m%d-%H%M%S)
    mkdir -p "$LOGDIR"
    log=$LOGDIR/sync-$stamp.log
    dest=$VM/staging/sync-src
    {
        echo "sync start $stamp dry_run=$dry"
        build_sync_tree "$dest"
        echo "managed tree ready"
        if ! vm_running; then
            echo "The VM is not running. The file list was checked and nothing was sent."
            exit 2
        fi
        if ! ip=$(guest_ip); then
            echo "The guest address is not known yet. Wait for open-vm-tools, then retry."
            exit 2
        fi
        echo "guest_ip=$ip"
        rsh="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$KEYDIR/known_hosts -o PasswordAuthentication=no -o BatchMode=yes"
        # The profile tree is owned by the host user. Do not copy that owner
        # onto guest system files. New files are created by root via sudo.
        local rsync_args=(-ai --no-owner --no-group -e "$rsh" --rsync-path="sudo rsync" --timeout=120)
        if (( dry )); then
            rsync_args+=(-n)
        fi
        echo "transfer:"
        rsync "${rsync_args[@]}" "$dest/" "dev@$ip:/" | tee "$LOGDIR/sync-$stamp.transfer"
        echo "owned-directory delete:"
        while IFS= read -r dir; do
            check_rel_path "$dir" || exit 2
            if [[ ! -d $dest/$dir ]] || [[ -z $(find "$dest/$dir" -mindepth 1 -print -quit) ]]; then
                echo "refusing to delete inside an empty owned directory: $dir"
                exit 2
            fi
            rsync "${rsync_args[@]}" --delete "$dest/$dir/" "dev@$ip:/$dir/"
        done < <(owned_dirs)
        if (( dry )); then
            echo "dry-run only; guest packages were not changed"
        else
            echo "package sync:"
            local pkgs missing
            pkgs=$(grep -h -E '^[^#[:space:]]' "$PROFILE/packages.x86_64" "$PROFILE/packages.d/lab.txt" | sort -u)
            missing=$(comm -23 <(printf '%s\n' "$pkgs") <(ssh_base "$ip" pacman -Qq | sort))
            if [[ -z $missing ]]; then
                echo "packages=in-sync"
            else
                echo "missing:"
                printf '%s\n' "$missing"
                # shellcheck disable=SC2086
                ssh_base "$ip" sudo pacman -S --needed --noconfirm -- $missing
            fi
            echo "dev access guard:"
            ssh_base "$ip" sudo bash -s <<'EOF'
set -euo pipefail
if [[ -L /etc/systemd/system/sshd.service && $(readlink /etc/systemd/system/sshd.service) == /dev/null ]]; then
    rm -f /etc/systemd/system/sshd.service
    ln -sfn /usr/lib/systemd/system/sshd.service /etc/systemd/system/multi-user.target.wants/sshd.service
fi
test -f /etc/sudoers.d/10-laden-dev
test -f /etc/ssh/sshd_config.d/99-laden-dev.conf
test ! -f /home/dev/.ssh/id_ed25519
EOF
        fi
        echo "reboot check:"
        if [[ -f $LOGDIR/sync-$stamp.transfer ]]; then
            reasons=$(reboot_reason <"$LOGDIR/sync-$stamp.transfer" || true)
        else
            reasons=""
        fi
        if [[ -n ${reasons:-} ]]; then
            echo "reboot-required=yes"
            printf '%s\n' "$reasons"
        else
            echo "reboot-required=no"
            echo "Wallpaper, menu, and application configuration do not need a guest reboot."
            echo "A new user picks up skel on the next login. A user who already has a wallpaper marker keeps that choice."
        fi
    } > >(tee "$log") 2>&1
}

cmd_ssh() {
    if [[ ${1:-} == -- ]]; then
        shift
    fi
    require_disk
    local ip
    if ! ip=$(guest_ip); then
        echo "The guest address is not known." >&2
        exit 2
    fi
    ssh_base "$ip" "$@"
}

main() {
    local cmd=${1:-}
    shift || true
    case "$cmd" in
        create) cmd_create "$@" ;;
        start) cmd_start "$@" ;;
        stop) cmd_stop "$@" ;;
        status) cmd_status "$@" ;;
        snapshot) cmd_snapshot "$@" ;;
        restore) cmd_restore "$@" ;;
        sync) cmd_sync "$@" ;;
        ssh) cmd_ssh "$@" ;;
        files) cmd_files "$@" ;;
        -h|--help|help|"") usage ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
