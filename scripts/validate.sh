#!/usr/bin/env sh
set -eu

python3 scripts/fap_guard.py
cargo fmt --check
cargo check
cargo clippy
cargo build --release

test -s target/thumbv7em-none-eabihf/release/kindled_spark.fap
python3 scripts/fap_guard.py --artifact
file target/thumbv7em-none-eabihf/release/kindled_spark.fap
