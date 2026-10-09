# Agent Reference: Flipper Interaction & Tooling

This document provides raw CLI commands and canonical references for interacting with the Flipper Zero device and developing the **Bible [BSB]** app.

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

This repo has two Flipper apps. The C app in `bible_bsb/` is the one that ships (`bible_bsb`, built with ufbt from that directory, installed at `/ext/apps/Media/bible_bsb.fap`). The Rust prototype in `src/` uses [flipperzero-rs](https://github.com/flipperzero-rs/flipperzero-rs). Its root `application.fam` defines an external build step via Cargo and still uses the package name `kindled_spark`.

### Prerequisites
```sh
# Ensure the Rust target is installed
rustup target add thumbv7em-none-eabihf
```

### Build
```sh
# C app. Run ufbt from bible_bsb/, not the repo root.
cd bible_bsb && ufbt

# Rust prototype
cargo build --release
sh scripts/validate.sh
```

Do not run `ufbt` from the repo root. The root `application.fam` has `sources=[]`
plus `fap_extbuild`, and ufbt rejects that before Cargo runs. Cargo is the build
path for the Rust app. Its `.fap` is:

```
target/thumbv7em-none-eabihf/release/kindled_spark.fap
```

The C app's `.fap` is `bible_bsb/dist/bible_bsb.fap`.

### Deploy
Close the running app first (`loader close`), then install the C app:

```sh
python3 /Users/user/.ufbt/current/scripts/storage.py \
  -p /dev/cu.usbmodemflip_Yxoybo1 \
  send -f bible_bsb/dist/bible_bsb.fap \
  /ext/apps/Media/bible_bsb.fap
```

The Rust prototype installs to `/ext/apps/Media/kindled_spark.fap`. One serial
connection at a time.

### Prepare BSB Data
The shipping C app bundles the chapter text. `fap_file_assets="assets"` installs
`bible_bsb/assets/bsb.pack` to `/ext/apps_assets/bible_bsb/bsb.pack`. Rebuild that
pack with:
```sh
python3 scripts/fetch_bsb.py --output bsb_sd/ --pack bible_bsb/assets/bsb.pack
```

Saved passages for the C app are stored at:
```
/ext/apps_data/bible_bsb/collection.json
```

The Rust prototype in `src/` still reads `/ext/apps_data/kindled_spark/`.

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
   - `src/main.rs`: `rt::manifest!(name = "Bible [BSB]", stack_size = 4096);`
   - `application.fam`: `stack_size=4 * 1026`
   - If still crashing, temporarily bump to `8192` as a diagnostic.

4. **Storage lifecycle** — Every `storage_file_open` failure path must call `storage_file_close()` before `storage_file_free()`. The Flipper firmware crashes if you free a file that was never closed, even when the open failed.

5. **Serial-only, one connection at a time** — The Flipper CLI cannot tolerate two simultaneous serial connections. Always run commands sequentially; never open `screen` and `flipper_cli.py` at the same time.

### Heap Fragmentation & Out-of-Memory Crashes

The Flipper Zero has very limited heap (~16–32KB free for FAPs). **OOM crashes are almost always heap fragmentation, not total memory exhaustion.**

**The Mistake:** `Vec::with_capacity(64000).resize(64000, 0)` allocates a **single contiguous 64KB block**. Even if the heap has 80KB total free space scattered in small chunks, this allocation fails because no 64KB hole exists. This was the root cause of the "out of memory" crash when loading chapters or saving passages.

**Symptoms:**
- Crash only on large chapters (Psalms 119 = 15KB JSON file) but works on small chapters
- Crash when saving a passage that was already loaded into memory
- Crash happens at `Vec::resize`, `Vec::with_capacity`, or `String::with_capacity` calls

**Detection:** On-device serial CLI:
```sh
free
```
Look at the heap free value. If it's > 64KB but your 64KB allocation still crashes, it's fragmentation.

**Fix — Chunked File Reads:**
Never allocate a large buffer upfront. Read in small fixed chunks (e.g., 1KB) and `extend_from_slice` into a `Vec` that grows incrementally:

```rust
const CHUNK: usize = 1024;
const MAX_TOTAL: usize = 20_000; // actual max file size, not a generous guess

let mut buf: Vec<u8> = Vec::new();
let mut chunk = [0u8; CHUNK];
let mut total: usize = 0;
loop {
    let n = storage_file_read(file, chunk.as_mut_ptr() as *mut c_void, CHUNK);
    if n == 0 || total + n > MAX_TOTAL {
        break;
    }
    buf.extend_from_slice(&chunk[..n]);
    total += n;
}
```

This avoids the single large allocation. The heap only needs 1KB contiguous at a time.

**Fix — Shrink Buffer Constants to Actual File Sizes:**
The original code used `MAX_FILE_SIZE: usize = 64_000` as a "generous" buffer size. The actual largest chapter file was only 15KB. Always measure:

```sh
find bsb_local_sd -name "*.json" -exec ls -la {} + | awk '{print $5, $9}' | sort -rn | head -5
```

Set `MAX_FILE_SIZE` to the actual maximum + margin (e.g., 20KB for a 15KB file), not an arbitrary large number.

**Fix — Don't Store Duplicate Data in RAM:**
The `Passage` struct originally held `verses: Vec<Verse>` alongside `state.lines: Vec<Line>` (the wrapped display lines). Both held the same verse text — ~40KB dead weight on large chapters. Removed `verses` from `Passage` entirely; verses are reloaded from SD on demand.

**Fix — Defragment Before Big Allocs:**
Before calling `load_collection()` (which needs a few KB), temporarily clear large heap consumers like `state.lines`, do the allocation, then reload:

```rust
state.lines.clear(); // frees scattered String chunks
let collection = load_collection(); // now has room for contiguous block
reload_lines(state); // restore display
```

**Rule of thumb for this app:**
- Chapter loader buffer: `20_000` (largest file is ~15KB)
- Collection loader buffer: `2_048` (collection.json is typically <1KB)
- Read chunk size: `1_024`
- Never use `resize()` on a Vec to pre-allocate a large contiguous block

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

4. If it crashes only after loading data / saving data, check **heap fragmentation** (see section above) before suspecting logic bugs.

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
