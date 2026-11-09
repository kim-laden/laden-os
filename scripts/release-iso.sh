#!/bin/bash
# SPDX-License-Identifier: MIT
# Release build. This is not part of the development VM workflow and it does
# not run unless you invoke it. It refuses to overwrite an ISO that is already
# in build/out, and it does not publish the result.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROFILE=$ROOT/profile/laden-os/profiledef.sh
version=$(sed -n 's/^iso_version="\(.*\)"/\1/p' "$PROFILE")
if [[ -z $version ]]; then
    echo "Could not read iso_version from $PROFILE" >&2
    exit 2
fi
name="laden-os-${version}-x86_64.iso"
dest=$ROOT/build/out/$name
if [[ -e $dest || -e $ROOT/build/out/${name}.sha256 ]]; then
    echo "Refusing to overwrite $dest" >&2
    echo "Bump iso_version in profile/laden-os/profiledef.sh before a release." >&2
    exit 2
fi

stamp=$(date +%Y%m%d-%H%M%S)
work=$ROOT/build/release/$stamp/work
out=$ROOT/build/release/$stamp/out
mkdir -p "$out"
echo "Release work directory: $work"
echo "This build does not replace the development VM and does not publish."

export LADEN_WORK=$work
export LADEN_OUT=$out
"$ROOT/scripts/build-iso.sh" 1

built=$(find "$out" -maxdepth 1 -type f -name 'laden-os-*.iso' | head -1)
if [[ -z ${built:-} || ! -f $built ]]; then
    echo "The release build did not produce an ISO." >&2
    exit 1
fi
if [[ -e $work/x86_64/airootfs/home/laden ]]; then
    echo "host home leaked into the release work root" >&2
    exit 1
fi
if find "$work/x86_64/airootfs" \( -name 'id_ed25519' -o -name '10-laden-dev' \) | grep -q .; then
    echo "development access leaked into the release work root" >&2
    exit 1
fi

echo "Scanning the ISO. A failed secret scan stops the release."
"$ROOT/scripts/scan-image.sh" "$built"

echo "Boot-testing the live image. A development VM boot does not replace this."
"$ROOT/scripts/test-boot.sh" both "$built"

cp -a "$built" "$dest"
if [[ -f $out/SHA256SUMS-$(basename "$built" .iso) ]]; then
    cp -a "$out/SHA256SUMS-$(basename "$built" .iso)" "$ROOT/build/out/"
fi
if [[ -f $out/PACKAGES-$(basename "$built" .iso).txt ]]; then
    cp -a "$out/PACKAGES-$(basename "$built" .iso).txt" "$ROOT/build/out/"
fi
echo "Release file: $dest"
echo "Not published. Secure Boot is unsigned and no GPG signature was added."
