#!/bin/bash
# SPDX-License-Identifier: MIT
# Build a Laden OS install image under build/install-vm/.
# This refuses host devices, the development VM disk, and sudo.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=$ROOT/build/install-vm
IMAGE=$DEST/laden-os-install.raw
ISO=$ROOT/build/out/laden-os-0.1.1-live-x86_64.iso
ISO_SUM=$ROOT/build/out/SHA256SUMS-laden-os-0.1.1-live-x86_64
PROFILE=$ROOT/profile/laden-os
UNSQUASH=$ROOT/build/host-tools/usr/bin/unsquashfs
ENGINE=$PROFILE/airootfs/usr/lib/laden-os/install-system
PASSWORD=$DEST/password
LOG=$DEST/logs/install.log

replace=0
if [[ ${1:-} == --replace ]]; then
    replace=1
elif [[ $# -gt 0 ]]; then
    echo "usage: scripts/install-disk.sh [--replace]" >&2
    exit 2
fi

refuse() {
    local path=$1
    case "$path" in
        /dev/*|*/dev/*)
            echo "refusing a host device path: $path" >&2
            exit 2
            ;;
    esac
    if [[ -b $path || -c $path ]]; then
        echo "refusing a block or character device: $path" >&2
        exit 2
    fi
}

refuse "$IMAGE"
refuse "$ISO"
if [[ -e $ROOT/build/dev-vm/laden-os-dev.raw ]]; then
    refuse "$ROOT/build/dev-vm/laden-os-dev.raw"
fi

if [[ ${LADEN_INSTALL_INNER:-0} != 1 ]]; then
    if [[ -n ${SUDO_UID:-} || $(id -u) -eq 0 ]]; then
        echo "Refusing to run through sudo or as the host root user." >&2
        exit 2
    fi
    mkdir -p "$DEST/logs"
    if [[ ! -f $PASSWORD ]]; then
        python3 -c 'import secrets,string; alphabet=string.ascii_lowercase+string.digits; print("".join(secrets.choice(alphabet) for _ in range(16)), end="")' >"$PASSWORD"
        chmod 600 "$PASSWORD"
    fi
    chmod 600 "$PASSWORD"
    echo $$ >"$DEST/install.pid"
    export LADEN_INSTALL_INNER=1
    exec unshare --fork --pid --mount --map-auto --map-root-user --setuid 0 --setgid 0 -- \
        "$ROOT/scripts/install-disk.sh" ${replace:+--replace}
fi

mkdir -p "$DEST/logs"
exec > >(tee -a "$LOG") 2>&1
echo "install-disk starting $(date -Is)"
if [[ ! -f $ISO ]]; then
    echo "Missing source ISO: $ISO" >&2
    exit 2
fi
expected=$(awk 'NR==1 { print $1 }' "$ISO_SUM")
got=$(sha256sum "$ISO" | awk '{ print $1 }')
if [[ $got != "$expected" ]]; then
    echo "Source ISO hash does not match $ISO_SUM" >&2
    exit 2
fi
args=(
    --image "$IMAGE"
    --image-root "$DEST"
    --repo "$ROOT"
    --iso "$ISO"
    --profile "$PROFILE"
    --unsquash "$UNSQUASH"
    --user laden
    --hostname laden
    --password-file "$PASSWORD"
    --serial-getty
    --size 28G
)
if [[ $replace == 1 ]]; then
    args+=(--replace)
fi
"$ENGINE" "${args[@]}"
echo "install-disk finished $(date -Is)"
