# Bible [BSB]

A Flipper Zero external app for browsing and saving BSB (Berean Standard Bible) scripture passages offline. Built in Rust using [flipperzero-rs](https://github.com/flipperzero-rs/flipperzero-rs).

## Features

- **Offline BSB reading** — Browse all 66 books by chapter and verse range. BSB text lives on your SD card (no network required).
- **Passage / verse-range support** — Read a full chapter or select a start/end verse range.
- **Save to collection** — Save passages locally in a Kindled-compatible JSON format.
- **Share via NFC** — Generate a `route.bible` URL and write it to a Flipper `.nfc` file for easy NFC tag sharing.
- **Paginated reader** — Word-wrapped text with Up/Down line scrolling and Left/Right page navigation.

## Installation

1. **Build BSB SD-card data** — The source `bsb.jsonl` dataset is hosted on Arweave at:
   `https://arweave.net/B6yeNb3lk_VkiIp-fTWVh13TlM94LjLK6kC63BPXa8s`

   Run the data script to download that dataset and build the Flipper chapter files:
   ```bash
   python3 scripts/fetch_bsb.py --output bsb_sd/
   ```
   If you already have the JSONL locally, pass it directly:
   ```bash
   python3 scripts/fetch_bsb.py --input /path/to/bsb.jsonl --output bsb_sd/
   ```
   Copy the contents of `bsb_sd/` to `/ext/apps_data/kindled_spark/bsb/` on your Flipper's SD card.

2. **Install the app** — Build and copy the `.fap` to your Flipper:
   ```bash
   cargo build --release
   # Copy target/thumbv7em-none-eabihf/release/kindled_spark.fap to /ext/apps/Media/
   ```

   To validate the app locally without launching it on the device:
   ```bash
   sh scripts/validate.sh
   ```

## Navigation

| Screen | Controls |
|--------|----------|
| **Book List** | Up/Down = scroll, OK = select book, Back = quit |
| **Chapter List** | D-pad = move, OK = select chapter, Back = back |
| **Verse Select** | Left/Right = switch mode (All / Range), Up/Down = adjust verse, OK = read |
| **Reader** | Up/Down = scroll line, Left/Right = page, OK short = menu, OK long = quick save, Back = back |
| **Action Menu** | Up/Down = select, OK = confirm (Save / Share NFC / Back) |

## route.bible Integration

Every saved passage generates a canonical `route.bible` URL using the BSB translation:
```
https://route.bible/jhn.3.16?v=BSB&src=kindled_spark
```

## Data Format

Saved passages are stored at `/ext/apps_data/kindled_spark/collection.json` using the Kindled web-app schema for future import compatibility.

## License

MIT. BSB text is public domain.
