#!/bin/bash
# Helpers for creating a Garmin Connect IQ developer signing key.
#
# Connect IQ PRGs must be signed with an RSA 4096-bit private key. The
# compiler accepts smaller keys, but the simulator rejects the resulting PRG at
# launch with "Signature check failed", which leaves the simulator on the splash
# screen before the app's UI lifecycle starts.

connectiq_key_bits() {
    local key="$1"
    openssl rsa -inform DER -in "$key" -noout -text 2>/dev/null \
        | sed -n 's/.*(\([0-9][0-9]*\) bit.*/\1/p' \
        | head -n 1
}

ensure_connectiq_dev_key() {
    local key="$1"
    local bits=""

    if [ -f "$key" ]; then
        bits="$(connectiq_key_bits "$key")"
        if [ "$bits" = "4096" ]; then
            return 0
        fi

        if [ -n "${CONNECTIQ_DEV_KEY:-}" ]; then
            echo "ERROR: CONNECTIQ_DEV_KEY points to an invalid signing key: $key" >&2
            echo "Expected a DER-encoded RSA 4096-bit private key, got: ${bits:-unreadable}." >&2
            exit 1
        fi

        echo "Replacing invalid Connect IQ signing key at $key (bits: ${bits:-unreadable}) ..."
    else
        echo "Creating Connect IQ signing key at $key ..."
    fi

    mkdir -p "$(dirname "$key")"
    local tmp_pem
    tmp_pem="$(mktemp)"

    openssl genrsa -out "$tmp_pem" 4096 >/dev/null 2>&1
    openssl pkcs8 -topk8 -inform PEM -outform DER -in "$tmp_pem" -out "$key" -nocrypt >/dev/null 2>&1
    rm -f "$tmp_pem"

    chmod 600 "$key"
}
