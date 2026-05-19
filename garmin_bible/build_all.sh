#!/bin/bash
# Build Bible BSB for all declared target devices
# Usage: ./build_all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONKEYC="/tmp/connectiq/sdk_zip/bin/monkeyc"
KEY="/tmp/dev_key.der"
OUT_DIR="$SCRIPT_DIR/bin"

# Target devices (must match manifest.xml <iq:product> ids)
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

mkdir -p "$OUT_DIR"

PASS=0
FAIL=0

for dev in "${DEVICES[@]}"; do
    echo ""
    echo "=== Building $dev ==="
    OUT_FILE="$OUT_DIR/bible_${dev}.prg"
    if "$MONKEYC" -f "$SCRIPT_DIR/monkey.jungle" -d "$dev" -y "$KEY" -o "$OUT_FILE" 2>&1; then
        echo "PASS: $dev"
        PASS=$((PASS + 1))
        ls -la "$OUT_FILE"
        SIZE=$(stat -c%s "$OUT_FILE" 2>/dev/null || stat -f%z "$OUT_FILE" 2>/dev/null)
        if [ "$SIZE" -gt 131072 ]; then
            echo "WARNING: $dev .prg is ${SIZE} bytes (> 128KB limit)"
        fi
    else
        echo "FAIL: $dev"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "========================================"
echo "Build summary: $PASS passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
