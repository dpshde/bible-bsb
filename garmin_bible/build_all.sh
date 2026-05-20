#!/bin/bash
# Build Bible BSB for all declared target devices
# Usage: ./build_all.sh [mode]
#   ./build_all.sh           — normal compilation (default)
#   ./build_all.sh typecheck — strict typecheck (-l 3) for all devices
#   ./build_all.sh test      — test compilation (-t) for all devices
#
# Requirements:
#   - monkeyc v9.1.0 at /tmp/connectiq/sdk_zip/bin/monkeyc
#   - RSA 4096-bit dev signing key at .developer_key.der, generated on demand
#     (or set CONNECTIQ_DEV_KEY to use a custom key)
#   - Device data at ~/.Garmin/ConnectIQ/Devices/
#
# Targets (must match manifest.xml <iq:product> ids):
#   instinct3solar45mm   — primary: 176x176 MIP, 1-bit, 5 buttons
#   instinct3amoled45mm  — 176x176 AMOLED, color
#   instincte40mm        — 176x176 MIP, 1-bit
#   instincte45mm        — 176x176 MIP, 1-bit
#   descentg2            — 176x176 MIP, dive computer
#   fenix7               — 260x260 MIP LCD, color, round
#   venu3                — 390x390 AMOLED, color, round, touch
#   d2mach1              — 260x260 AMOLED, color, round
#   approachs50          — 260x260 AMOLED, color, round
#
# Note on .prg size: The compiled .prg includes embedded offline chapter JSON
# resources (~450 chapters). A 2–3 MB .prg is expected and acceptable. The
# 128 KB limit applies to runtime heap, not the on-disk .prg file.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONKEYC="/tmp/connectiq/sdk_zip/bin/monkeyc"
KEY="${CONNECTIQ_DEV_KEY:-$SCRIPT_DIR/.developer_key.der}"
OUT_DIR="$SCRIPT_DIR/bin"

source "$SCRIPT_DIR/scripts/dev_key.sh"

MODE="${1:-build}"

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

EXTRA_FLAGS=""
OUT_SUFFIX=""
case "$MODE" in
    typecheck)
        EXTRA_FLAGS="-l 3"
        OUT_SUFFIX="_typecheck"
        echo "=== STRICT TYPECHECK (-l 3) FOR ALL DEVICES ==="
        ;;
    test)
        EXTRA_FLAGS="-t"
        OUT_SUFFIX="_test"
        echo "=== TEST COMPILATION (-t) FOR ALL DEVICES ==="
        ;;
    build)
        echo "=== BUILDING FOR ALL DEVICES ==="
        ;;
    *)
        echo "Usage: $0 [build|typecheck|test]"
        exit 1
        ;;
esac

mkdir -p "$OUT_DIR"
ensure_connectiq_dev_key "$KEY"

PASS=0
FAIL=0

for dev in "${DEVICES[@]}"; do
    echo ""
    echo "--- $dev ---"
    OUT_FILE="$OUT_DIR/bible_${dev}${OUT_SUFFIX}.prg"
    if "$MONKEYC" $EXTRA_FLAGS -f "$SCRIPT_DIR/monkey.jungle" -d "$dev" -y "$KEY" -o "$OUT_FILE" 2>&1; then
        echo "PASS: $dev"
        PASS=$((PASS + 1))
        if [ "$MODE" = "build" ]; then
            ls -la "$OUT_FILE"
            SIZE=$(stat -c%s "$OUT_FILE" 2>/dev/null || stat -f%z "$OUT_FILE" 2>/dev/null)
            echo "  Size: ${SIZE} bytes"
            # Note: .prg > 128KB is expected because offline chapter JSON resources
            # (~450 chapters) are embedded. Runtime heap stays under 128KB.
        fi
    else
        echo "FAIL: $dev"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "========================================"
echo "Summary: $PASS passed, $FAIL failed (${#DEVICES[@]} devices)"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
