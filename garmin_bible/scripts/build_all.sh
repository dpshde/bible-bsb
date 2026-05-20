#!/bin/bash
# Build the Bible [BSB] app for all target devices
# Usage: ./garmin_bible/scripts/build_all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/dev_key.sh"

SDK="/tmp/connectiq/sdk_zip/bin/monkeyc"
KEY="${CONNECTIQ_DEV_KEY:-$PROJECT_DIR/.developer_key.der}"
PROJECT="$PROJECT_DIR"
OUTDIR="${PROJECT}/bin"

DEVICES=(
    instinct3solar45mm
    instinct3amoled45mm
    instincte40mm
    instincte45mm
    descentg2
    fenix7
    venu3
    d2mach1
    approachs50
)

mkdir -p "${OUTDIR}"
ensure_connectiq_dev_key "$KEY"

for device in "${DEVICES[@]}"; do
    echo "=== Building for ${device} ==="
    "${SDK}" -f "${PROJECT}/monkey.jungle" -d "${device}" -y "${KEY}" -o "${OUTDIR}/bible_${device}.prg"
done

echo ""
echo "=== All builds successful ==="
ls -la "${OUTDIR}"/*.prg
