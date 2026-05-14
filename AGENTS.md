# Agent Reference: Flipper Interaction & Tooling

This document provides raw CLI commands and canonical references for interacting with the Flipper Zero device and developing the **Kindled Spark** app.

## Connected Device

On this machine, the Flipper mounts as:
- `/dev/cu.usbmodemflip_Yxoybo1`
- `/dev/tty.usbmodemflip_Yxoybo1`

## Raw Serial CLI

Connect to the Flipper's built-in CLI over USB:

```sh
# screen (Ctrl+A, K to exit)
screen /dev/cu.usbmodemflip_Yxoybo1 115200

# picocom
picocom -b 115200 /dev/cu.usbmodemflip_Yxoybo1

# minicom
minicom -D /dev/cu.usbmodemflip_Yxoybo1 -b 115200
```

Common onboard CLI commands:
- `help` — List all commands
- `info` — Device and firmware info
- `storage` — SD card file operations (`storage list /ext`, `storage read /ext/apps/Media/kindled_spark.fap`, etc.)
- `loader` — Load/unload apps (`loader open Media`, `loader list`, etc.)
- `subghz` — Sub-GHz radio control
- `nfc` — NFC read/write/emu
- `ir` — Infrared transmit/receive
- `gpio` — GPIO pin control
- `update` — OTA update commands
- `date`, `free`, `ps`, `log` — System utilities

## qFlipper

### Install Paths
- **macOS App:** `/Applications/qFlipper.app`
- **macOS Binary:** `/Applications/qFlipper.app/Contents/MacOS/qFlipper`
- **Linux/Windows:** Installed via package manager or portable binary (see [qFlipper repo](https://github.com/flipperdevices/qFlipper))

### qFlipper CLI
```sh
# List connected devices
qFlipper --cli list

# Install a .fap app
qFlipper --cli install ./target/thumbv7em-none-eabihf/release/kindled_spark.fap

# Flash firmware
qFlipper --cli flash /path/to/firmware.tgz

# Backup Flipper to archive
qFlipper --cli backup ./backup.tar.gz

# Restore from archive
qFlipper --cli restore ./backup.tar.gz
```

## Project Build & Deploy

This app is built in Rust using [flipperzero-rs](https://github.com/flipperzero-rs/flipperzero-rs). The `application.fam` defines an external build step via Cargo.

### Prerequisites
```sh
# Ensure the Rust target is installed
rustup target add thumbv7em-none-eabihf
```

### Build
```sh
# Via Cargo directly
cargo build --release

# Offline validation without touching the device
sh scripts/validate.sh
```

`ufbt` is present at `./.venv/bin/ufbt`, but this Rust app's `application.fam`
uses `sources=[]` plus `fap_extbuild`, and the current `ufbt` SCons pipeline
rejects empty source lists before it can use the Rust-built `.fap`. Treat Cargo
as the authoritative local build path for this repo.

The compiled `.fap` is output to:
```
target/thumbv7em-none-eabihf/release/kindled_spark.fap
```

### Deploy
Copy the `.fap` to the Flipper SD card at:
```
/ext/apps/Media/kindled_spark.fap
```

Or install via qFlipper CLI (see above).

### Prepare BSB Data
Before running the app, populate the SD card with Berean Standard Bible chapter files:
```sh
python3 scripts/fetch_bsb.py --output bsb_sd/
```
Then copy `bsb_sd/` contents to the Flipper:
```
/ext/apps_data/kindled_spark/bsb/
```

Saved passages are stored at:
```
/ext/apps_data/kindled_spark/collection.json
```

## Debugging & Runtime Learnings

### BusFault Root-Cause Checklist for `flipperzero-rs` FAPs

If your Rust FAP causes a BusFault / HardFault on launch, check in this order:

1. **Wrong linker flags** — The most common cause. The official `flipperzero-rs` template requires `--relocatable` link mode, NOT `--emit-relocs` on a normal executable.
   - Correct `.cargo/config.toml`:
     ```toml
     [target.thumbv7em-none-eabihf]
     rustflags = [
         "-Z", "no-unique-section-names",
         "-C", "target-cpu=cortex-m4",
         "-C", "panic=abort",
         "-C", "debuginfo=0",
         "-C", "opt-level=z",
         "-C", "embed-bitcode=yes",
         "-C", "lto=yes",
         "-C", "link-args=--script=flipperzero-rt.ld --Bstatic --relocatable --discard-all --strip-all --lto-O3 --lto-whole-program-visibility",
     ]
     ```
   - Wrong flags (will BusFault): `--emit-relocs`, `-Tflipperzero-rt.ld` without `--relocatable`.
   - The `-Z no-unique-section-names` flag is also required; without it the FAP will have `.text.*` unique sections that break relocation packaging.

2. **Do NOT run `fastfap.py` on relocatable Rust FAPs** — The `fastfap.py` script from the ufbt toolchain corrupts relocatable Rust output. Install the raw Cargo-built `.fap` directly. The `validate.sh` in this repo skips `fastfap.py` entirely.

3. **Stack size** — Set explicitly in both places:
   - `src/main.rs`: `rt::manifest!(name = "Kindled Spark", stack_size = 4096);`
   - `application.fam`: `stack_size=4 * 1026`
   - If still crashing, temporarily bump to `8192` as a diagnostic.

4. **Storage lifecycle** — Every `storage_file_open` failure path must call `storage_file_close()` before `storage_file_free()`. The Flipper firmware crashes if you free a file that was never closed, even when the open failed.

5. **Serial-only, one connection at a time** — The Flipper CLI cannot tolerate two simultaneous serial connections. Always run commands sequentially; never open `screen` and `flipper_cli.py` at the same time.

### Isolation Debugging Strategy

When a Rust FAP crashes and you don't know why, binary-search the fault:

1. Reduce `main()` to the absolute minimum:
   ```rust
   fn main(_args: Option<&CStr>) -> i32 {
       loop {}
   }
   ```
   If this crashes, the problem is linker/packaging, not application code.

2. Add back one API call at a time:
   - `furi_message_queue_alloc` → `view_port_alloc` → `view_port_draw_callback_set` → `view_port_input_callback_set` → `furi_record_open(c"gui")` → `gui_add_view_port`
   - The crash boundary tells you exactly which API or callback is at fault.

3. If the minimal no-import FAP runs but adding API calls crashes, suspect the linker flags first, then null-pointer handling, then C string lifetime issues.

### Canvas Layout Rules

The Flipper Zero screen is 128x64 pixels. Common layout constants used in this app:

- `FontPrimary` (5x7 font) + 1px gap = ~6px char width, 8px char height
- `FontSecondary` = smaller font for headers/indicators
- Header text at y=8, divider line at y=10
- Content starts at y=16 (6px padding below header line)
- `LINE_HEIGHT = 12` (8px char + 4px inter-line spacing) for scripture readability
- Bottom margin at y=62 (leaves 2px gap above 64px edge)

## RPC / Automation

- **Protobuf Specification:** [flipperzero-protobuf](https://github.com/flipperdevices/flipperzero-protobuf)
- **Python Bindings:** [flipperzero_protobuf_py](https://github.com/flipperdevices/flipperzero_protobuf_py)

If the Python bindings are installed, automation is available via:
```sh
python3 -m flipper --help
```

## Reference Links

### Flipper Zero
- [Flipper Zero Firmware](https://github.com/flipperdevices/flipperzero-firmware)
- [Flipper Zero Apps Catalog](https://github.com/flipperdevices/flipper-application-catalog)
- [Flipper Zero 3D Models](https://github.com/flipperdevices/flipperzero-3d-models)
- [Flipper Zero ST-LINK V3MODS Module](https://github.com/flipperdevices/flipperzero-devboard-stlinkv3)
- [WiFi Board/Debug Probe Firmware](https://github.com/flipperdevices/blackmagic-esp32-s2)

### Companion Applications
- [qFlipper](https://github.com/flipperdevices/qFlipper) — Win/Mac/Lin desktop companion
- [Flipper Android App](https://github.com/flipperdevices/Flipper-Android-App)
- [Flipper iOS App](https://github.com/flipperdevices/Flipper-iOS-App)

### Tools & Libraries
- [Flipper Zero Application Build Tool (ufbt)](https://github.com/flipperdevices/flipperzero-ufbt) — micro Flipper Build Tool, designed for easy flipper application development
- [Flipper Zero Protobuf Specification](https://github.com/flipperdevices/flipperzero-protobuf) — Flipper RPC message specification
- [Flipper Zero Sample Application](https://github.com/flipperdevices/flipperzero-catalog-sample-app) — Catalog-ready Flipper Application Sample
- [Flipper Zero ufbt GitHub Action](https://github.com/flipperdevices/flipperzero-ufbt-action) — CI/CD automation for your flipper apps
- [Flipper Zero Protobuf Python Bindings](https://github.com/flipperdevices/flipperzero_protobuf_py) — Used for various automation tasks
- [Flipper Zero Toolchain](https://github.com/flipperdevices/flipperzero-toolchain) — Compiler and all necessary tools to build firmware
- [LibUSB STM32](https://github.com/flipperdevices/libusb_stm32) — STM32 USB stack implementation
- [STM32WB COPRO](https://github.com/flipperdevices/stm32wb_copro) — Compact version of STM WPAN library
- [STM32WB COPRO Scripts](https://github.com/flipperdevices/stm32wb_copro_scripts) — Helper scripts for `stm32wb_copro`
- [GCC MAP file parser](https://github.com/flipperdevices/map-gcc-parser-python) — Tool that helps us analyze firmware growth
