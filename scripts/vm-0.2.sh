#!/bin/bash
# SPDX-License-Identifier: MIT
# Start a throwaway QEMU/KVM VM for Laden OS install tests (file-backed only).
#   vm-0.2.sh DIR bios|uefi live ISO   -> boot the ISO with DIR/disk.qcow2 attached (created blank if missing)
#   vm-0.2.sh DIR bios|uefi disk       -> boot DIR/disk.qcow2 only
# Control it with scripts/vmctl.py DIR ...
set -euo pipefail
DIR=$1 FW=$2 MODE=$3 ISO=${4:-}
mkdir -p "$DIR"
[[ -f $DIR/disk.qcow2 ]] || qemu-img create -q -f qcow2 "$DIR/disk.qcow2" 40G
fw=()
if [[ $FW == uefi ]]; then
  [[ -f $DIR/vars.fd ]] || cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$DIR/vars.fd"
  fw=(-drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd -drive if=pflash,format=raw,file="$DIR/vars.fd")
fi
media=()
if [[ $MODE == live ]]; then
  ISO=$(readlink -f "$ISO"); [[ -f $ISO && ! -b $ISO ]] || { echo "ISO must be a regular file" >&2; exit 2; }
  media=(-drive file="$ISO",media=cdrom,readonly=on,if=none,id=cd0 -device ide-cd,drive=cd0,bootindex=0)
fi
rm -f "$DIR"/{qmp,serial,mon}.sock
exec nice -n 19 ionice -c3 qemu-system-x86_64 -machine q35,accel=kvm,vmport=off -cpu host -m 6144 -smp 4 \
  "${media[@]}" -drive file="$DIR/disk.qcow2",if=none,id=d0,format=qcow2 -device virtio-blk-pci,drive=d0,bootindex=1 \
  -nic user,model=virtio-net-pci -vga virtio -display none -device qemu-xhci -device usb-tablet \
  -chardev socket,id=s0,path="$DIR/serial.sock",server=on,wait=off,logfile="$DIR/serial-$MODE.log",logappend=on -serial chardev:s0 \
  -qmp unix:"$DIR/qmp.sock",server,nowait -monitor unix:"$DIR/mon.sock",server,nowait \
  -name "laden-vm-$(basename "$DIR")" "${fw[@]}"
