#!/bin/bash
# Build a single Connect IQ target device
# Usage: ./build.sh <device-id>
# Example: ./build.sh instinct3solar45mm

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="${1:-instinct3solar45mm}"
MONKEYC="/tmp/connectiq/sdk_zip/bin/monkeyc"
KEY="/tmp/dev_key.der"
OUT_DIR="$SCRIPT_DIR/bin"
OUT_FILE="$OUT_DIR/bible_${DEVICE}.prg"

if [ -z "$DEVICE" ]; then
    echo "Usage: $0 <device-id>"
    echo "Example: $0 instinct3solar45mm"
    exit 1
fi

mkdir -p "$OUT_DIR"

echo "Building Bible BSB for $DEVICE ..."
"$MONKEYC" -f "$SCRIPT_DIR/monkey.jungle" -d "$DEVICE" -y "$KEY" -o "$OUT_FILE"
echo "Output: $OUT_FILE"
ls -la "$OUT_FILE"
