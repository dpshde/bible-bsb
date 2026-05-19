#!/bin/bash
# Build Bible BSB for a single Connect IQ target device
# Usage: ./build.sh <device-id>
# Example: ./build.sh instinct3solar45mm
#
# Available devices (must match manifest.xml <iq:product> ids):
#   instinct3solar45mm   — 176x176 MIP, 1-bit, 5 buttons (primary target)
#   instinct3amoled45mm  — 176x176 AMOLED, color
#   instincte40mm        — 176x176 MIP, 1-bit
#   instincte45mm        — 176x176 MIP, 1-bit
#   descentg2            — 176x176 MIP, dive computer
#   fenix7               — 260x260 MIP LCD, color, round
#   venu3                — 390x390 AMOLED, color, round, touch
#   d2mach1              — 260x260 AMOLED, color, round
#   approachs50          — 260x260 AMOLED, color, round
#
# For all devices at once, use ./build_all.sh
# For strict typecheck, use ./build_all.sh typecheck
# For test compilation, use ./build_all.sh test

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="${1:-instinct3solar45mm}"
MONKEYC="/tmp/connectiq/sdk_zip/bin/monkeyc"
KEY="/tmp/dev_key.der"
OUT_DIR="$SCRIPT_DIR/bin"
OUT_FILE="$OUT_DIR/bible_${DEVICE}.prg"

# DEVICE is always set via default above, but we keep a basic
# argument check for any future expansion.
if [ $# -gt 1 ]; then
    echo "Usage: $0 [device-id]"
    echo "Example: $0 instinct3solar45mm"
    echo ""
    echo "Available devices:"
    echo "  instinct3solar45mm instinct3amoled45mm instincte40mm instincte45mm"
    echo "  descentg2 fenix7 venu3 d2mach1 approachs50"
    exit 1
fi

mkdir -p "$OUT_DIR"

echo "Building Bible BSB for $DEVICE ..."
"$MONKEYC" -f "$SCRIPT_DIR/monkey.jungle" -d "$DEVICE" -y "$KEY" -o "$OUT_FILE"
echo "Output: $OUT_FILE"
ls -la "$OUT_FILE"
