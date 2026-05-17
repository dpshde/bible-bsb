# Bible [BSB] — Comprehensive Feature Inventory

> Generated from exhaustive analysis of all source files, build configuration, scripts, and data formats. This document exists to enable a full C-language reimplementation of the app.

---

## 1. App Overview

| Property | Value |
|----------|-------|
| **App Name** | Bible [BSB] |
| **App ID** | `kindled_spark` |
| **Category** | Media |
| **Version** | 1.0 |
| **Author** | dpshde |
| **Description** | Browse and save BSB scripture passages with route.bible NFC sharing |
| **Entry Point** | `kindled_spark_app` |
| **Stack Size** | 4 * 1024 = 4096 bytes |
| **Build System** | Rust via Cargo, invoked by `application.fam` via `fap_extbuild` |
| **Target** | `thumbv7em-none-eabihf` (Cortex-M4) |

The app is a Flipper Zero external FAP built with `flipperzero-rs` (v0.16.0). It uses `no_std` / `no_main`, allocates heap via `flipperzero-alloc`, and interfaces with the Flipper firmware through `flipperzero-sys` and `flipperzero-rt`.

---

## 2. File Inventory

### 2.1 Source Files (`src/`)

| File | Lines | Responsibility |
|------|-------|---------------|
| `src/main.rs` | ~95 | Entry point, event loop, view_port lifecycle, GUI registration, input queue, draw/input callbacks |
| `src/models.rs` | ~140 | Core data types: `Verse`, `Passage`, `CollectionEntry`; display/canonical ref formatting; `u16_to_string` helper |
| `src/books.rs` | ~145 | Static Bible metadata: OSIS codes, book names, chapter counts, per-chapter max-verse tables, OT/NT split constant |
| `src/bsb_loader.rs` | ~165 | SD-card JSON chapter loader, minimal no-alloc JSON verse extractor, chunked file reads |
| `src/storage.rs` | ~380 | `collection.json` read/write via streaming JSON writer; `build_kindled_json` for NFC export; verse loading for saved entries |
| `src/renderer.rs` | ~110 | Canvas word-wrap & pagination for 128×64 screen; `Line` struct; `wrap_verses`, `render_page`, `total_pages` |
| `src/route_url.rs` | ~55 | Canonical `route.bible` URL builder from passage components |
| `src/nfc_share.rs` | ~340 | NTAG215 NDEF URL/text emulation, Flipper `.nfc` file writer, listener callbacks, TLV page layout |
| `src/views/mod.rs` | ~100 | View router: `AppView` enum, `AppState` struct, `InputEvent`, `VerseSelectMode`, `draw_current_view`, `handle_input` |
| `src/views/book_list.rs` | ~140 | Book list view with alphabet filter, scrollable list, selection highlight, scroll indicator |
| `src/views/book_filter.rs` | ~95 | Filter grid view (22 filter options), grid navigation, scroll indicator |
| `src/views/chapter_list.rs` | ~120 | Chapter grid view (5 columns), scrollable chapter grid for selected book |
| `src/views/verse_select.rs` | ~170 | Verse selection: "All verses" or start/end range, Up/Down/Left/Right navigation |
| `src/views/reader.rs` | ~210 | Scripture reader with header, paginated text, page indicator, toast overlay, action menu, save/share handlers |
| `src/views/collection.rs` | ~150 | Saved passages list, read saved passage, delete (long-OK), NFC bulk export, empty state |
| `src/views/nfc_share.rs` | ~80 | NFC emission waiting screen with animated pulsing dots, URL preview, cancel instructions |

### 2.2 Build & Configuration Files

| File | Responsibility |
|------|---------------|
| `application.fam` | Flipper app manifest: `appid`, `name`, `fap_category`, `stack_size`, `fap_extbuild` pointing to Cargo-built `.fap` |
| `Cargo.toml` | Rust package manifest: `edition = "2024"`, dependencies on `flipperzero-alloc/sys/rt` v0.16.0, binary target `kindled_spark.fap` |
| `.cargo/config.toml` | Target specification and critical linker flags: `--relocatable`, `-Z no-unique-section-names`, LTO, `opt-level=z` |
| `icon.png` | 10×10 app icon for Flipper app browser |

### 2.3 Scripts (`scripts/`)

| File | Responsibility |
|------|---------------|
| `scripts/fetch_bsb.py` | Downloads `bsb.jsonl` from Arweave, parses per-chapter, writes JSON chapter files to `bsb_sd/{osis_lower}/{chapter}.json` |
| `scripts/fap_guard.py` | Offline safety checks: validates `.cargo/config.toml` rustflags, runtime manifest, no large stack arrays, ELF/FAP metadata, SDK API imports |
| `scripts/validate.sh` | Orchestrates `fap_guard.py` → `cargo fmt --check` → `cargo check` → `cargo clippy` → `cargo build --release` → `fap_guard.py --artifact` |
| `scripts/flipper_cli.py` | Runs a Flipper CLI command over USB CDC using `FlipperStorage` |
| `scripts/flipper_raw_cmd.py` | Sends raw serial command to Flipper and prints response until prompt/timeout |

---

## 3. Data Structures (Complete)

### 3.1 Core Models (`src/models.rs`)

```rust
pub struct Verse {
    pub number: u16,    // Verse number (1-based)
    pub text: String,   // Verse text content (max 512 chars after sanitization)
}

pub struct Passage {
    pub book_index: usize,   // 0–65 index into OSIS_BOOK_CODES / OSIS_BOOK_NAMES
    pub chapter: u16,        // Chapter number
    pub start_verse: u16,    // 0 = "all verses", otherwise start of range
    pub end_verse: u16,      // End of range (inclusive)
}

pub struct CollectionEntry {
    pub scripture_ref: String,          // Canonical OSIS reference (e.g., "JHN.3.16")
    pub scripture_display_ref: String,  // Human-readable (e.g., "John 3:16")
    pub scripture_translation: String,  // Always "BSB"
    pub book_index: usize,
    pub chapter: u16,
    pub start_verse: u16,
    pub end_verse: u16,
    pub captured_at: String,            // ISO timestamp (currently hardcoded to "2026-01-01T00:00:00Z")
    pub note: String,                   // Always empty string
}
```

**Methods on `Passage`:**
- `display_ref()` → human-readable string: `"John 3:16"` or `"John 3:16-18"`
- `canonical_ref()` → OSIS-style string: `"JHN.3.16"` or `"JHN.3.16-JHN.3.18"`

### 3.2 Rendering Types (`src/renderer.rs`)

```rust
pub struct Line {
    pub text: String,           // Wrapped line of text ready for canvas draw
    pub is_verse_number: bool,  // True if this line contains the verse number prefix
    pub verse_number: u16,      // The verse this line belongs to
}
```

### 3.3 View State (`src/views/mod.rs`)

```rust
pub struct AppState {
    pub current_view: AppView,            // Active screen enum
    pub selected_book: usize,             // Currently selected book (0–65)
    pub selected_chapter: u16,            // Currently selected chapter (1–150)
    pub selected_start_verse: u16,        // Verse range start
    pub selected_end_verse: u16,          // Verse range end
    pub verse_select_mode: VerseSelectMode,
    pub book_filter_idx: usize,           // 0–21 filter index
    pub scroll_offset: usize,             // Reader line scroll offset
    pub book_scroll: usize,               // Book list scroll offset
    pub collection_scroll: usize,         // Collection list scroll offset
    pub action_menu_selection: usize,     // 0–2 menu item index
    pub passage: Option<Passage>,         // Currently loaded passage
    pub collection: Vec<CollectionEntry>, // In-memory saved passages
    pub collection_loaded: bool,          // True after first load from SD
    pub lines: Vec<Line>,                 // Cached wrapped display lines
    pub toast_message: Option<String>,   // Current toast text
    pub toast_timer: u32,                 // Frames remaining (60 ≈ 2s @ 30fps)
    pub reader_came_from_collection: bool,
    pub nfc_url: Option<String>,          // URL being emitted
    pub nfc_emitting: bool,
    pub nfc_is_export: bool,              // True if emitting bulk JSON export
}

pub enum AppView {
    BookList,      // Browse/select book
    BookFilter,    // Alphabet filter grid
    ChapterList,   // Chapter grid for selected book
    VerseSelect,   // All vs. verse range selection
    Reader,        // Paginated scripture text
    Collection,    // Saved passages list
    ActionMenu,    // Reader overlay menu
    NfcShare,      // NFC emission waiting screen
}

pub enum VerseSelectMode {
    All,                // Read all verses in chapter
    RangeSelectingStart,// User is picking start verse
    RangeSelectingEnd,  // User is picking end verse
}

pub struct InputEvent {
    pub key: sys::InputKey,       // Up, Down, Left, Right, Ok, Back
    pub input_type: sys::InputType, // Press, Repeat, Short, Long
}
```

---

## 4. Screen-by-Screen Feature Breakdown

### 4.1 Book List (`src/views/book_list.rs`)

**Visual Layout:**
- Header line at y=10: `"< All >"` or `"< A >"` etc. showing active filter
- Horizontal divider at y=12
- Book names listed vertically, LINE_HEIGHT=10, MARGIN_X=2
- Selected book: inverted highlight (black box, white text)
- Scroll indicator: 2px-wide thumb on right edge at x=126

**Filter System:**
- 22 filter options: `"All"` + 21 initial letters: `A, C, D, E, G, H, I, J, K, L, M, N, O, P, R, S, T, Z, 1, 2, 3`
- Books matching filter (by first alphabetic character or first char equals filter) are shown
- `get_filtered_books(filter_idx)` returns `Vec<usize>` of matching book indices

**Input Handling:**
| Key | Action |
|-----|--------|
| **Up** (Press/Repeat) | Move selection up (wraps around) |
| **Down** (Press/Repeat) | Move selection down (wraps around) |
| **Left** (Short) | Go to Collection view (loads collection from SD if not loaded) |
| **Right** (Short) | Go to BookFilter view |
| **OK** (Short) | Go to ChapterList for selected book |
| **Back** (Short) | If filter active → reset to "All"; if "All" → **quit app** |

**Scroll Behavior:**
- `book_scroll` tracks first visible index
- Selection changes auto-scroll the list to keep selected item visible
- `max_visible = (64 - HEADER_HEIGHT - 2) / LINE_HEIGHT` ≈ 5 books visible

---

### 4.2 Book Filter (`src/views/book_filter.rs`)

**Visual Layout:**
- Header: `"< Select Filter"` at y=10
- Divider at y=12
- 5-column grid of filter options, each cell 25×14 pixels
- 3 rows visible at a time
- Selected cell: inverted highlight
- Scroll indicator for rows

**Input Handling:**
| Key | Action |
|-----|--------|
| **Up** (Press/Repeat) | Move up one row |
| **Down** (Press/Repeat) | Move down one row (snaps to last item if partial row) |
| **Left** (Press/Repeat) | Move left; from `"All"` (index 0) → go back to BookList |
| **Right** (Press/Repeat) | Move right |
| **OK / Back** (Short) | Apply filter and return to BookList (resets `selected_book` to first match, `book_scroll = 0`) |

---

### 4.3 Chapter List (`src/views/chapter_list.rs`)

**Visual Layout:**
- Header: book name at y=10
- Divider at y=12
- 5-column grid of chapter numbers, cell 24×14
- 3 rows visible
- Selected chapter: inverted highlight
- Scroll indicator

**Input Handling:**
| Key | Action |
|-----|--------|
| **Up** (Press/Repeat) | Move up by 5 chapters |
| **Down** (Press/Repeat) | Move down by 5 chapters (clamped to max) |
| **Left** (Press/Repeat) | Decrement chapter by 1 |
| **Right** (Press/Repeat) | Increment chapter by 1 |
| **OK** (Short) | Go to VerseSelect; reset mode to `All`, verses to 1 |
| **Back** (Short) | Return to BookList |

---

### 4.4 Verse Select (`src/views/verse_select.rs`)

**Visual Layout:**
- Header: `"{Book} {Chapter}"` at y=10
- Divider at y=12
- Three selectable rows at y positions 22, 34, 46:
  1. `"All verses"`
  2. `"Start: {n}"`
  3. `"End: {n}"`
- Selected row: inverted highlight
- Bottom hint (FontSecondary): context-sensitive help at y=60

**Input Handling:**
| Key | Action |
|-----|--------|
| **Up** (Press/Repeat) | Move selection: End → Start → All |
| **Down** (Press/Repeat) | Move selection: All → Start → End |
| **Left** (Press/Repeat) | If Start mode: decrement start verse; If End mode: decrement end verse (min = start) |
| **Right** (Press/Repeat) | If Start mode: increment start verse (auto-bumps end if needed); If End mode: increment end verse (clamped to `actual_max`) |
| **OK** (Short) | Load chapter from SD, filter to range if needed, wrap verses, set passage, go to Reader |
| **Back** (Short) | Return to ChapterList |

**Verse Count Lookup:**
- Uses `books::max_verse_for_chapter(book_index, chapter)`
- Hardcoded tables for Genesis (ch. 1–10), Psalms (all 150 chapters), John (all 21 chapters)
- Fallback: 40 verses for unknown chapters

---

### 4.5 Reader (`src/views/reader.rs`)

**Visual Layout:**
- Header: passage display ref (FontSecondary) at y=8
- Divider line at y=10
- Text content starts at y=16 (6px padding below header line)
- `LINE_HEIGHT = 12` pixels per line
- Page indicator (if >1 page): `"{current}/{total}"` at bottom-right
- Toast overlay: centered black box with white text, 14px tall, ~2 second duration

**Input Handling:**
| Key | Action |
|-----|--------|
| **Up** (Press/Repeat) | Jump to previous verse's first line |
| **Down** (Press/Repeat) | Jump to next verse's first line |
| **Left** (Press/Repeat) | Scroll up by 1 line |
| **Right** (Press/Repeat) | Scroll down by 1 line |
| **OK** (Long) | Quick save passage to collection |
| **OK** (Short) | Open Action Menu |
| **Back** (Short) | If `reader_came_from_collection` → Collection; else → VerseSelect |

**Navigation by Verse:**
- `next_verse_offset(lines, current)` finds first line with a higher `verse_number` than current
- `prev_verse_offset(lines, current)` handles two cases:
  - If current line is NOT the first line of its verse → jump to that verse's first line
  - If current line IS the first line → jump to previous verse's first line (or line 0)

**Action Menu (overlay screen `AppView::ActionMenu`):**
- 3 items: `"Save to collection"`, `"Share via NFC"`, `"Back to reading"`
- Inverted highlight selection
- **Up/Down**: move selection
- **OK**: execute selected action
- **Back**: cancel, return to Reader

**Save Logic (`do_save`):**
1. Clear `state.lines` to defragment heap before loading collection
2. Load collection from SD if not already in memory
3. Check idempotency: skip if `scripture_ref` already exists → toast `"Already saved"`
4. Create `CollectionEntry` with current passage data, `"BSB"` translation, hardcoded timestamp
5. Append to collection vector
6. Save to `collection.json` via streaming writer
7. Reload lines from SD (restore reader display)
8. Restore scroll offset
9. Toast `"Saved!"` or `"Save failed"`

**NFC Share Logic (`do_nfc_share`):**
1. Build `route.bible` URL from passage
2. Store URL in `state.nfc_url`
3. Call `nfc_share::start_emulation(&url)`
4. If success → go to `NfcShare` view
5. If fail → toast `"NFC failed"`, reset state

---

### 4.6 Collection (`src/views/collection.rs`)

**Visual Layout:**
- Header: `"Collection >"` at y=10
- Divider at y=12
- List of saved passage display refs, `LINE_H = 12`
- Selected entry: inverted highlight
- Empty state: `"No saved passages"` and `"Back to home"` at y=30/44
- Bottom hint: `"L=export OK=read"` at y=62

**Input Handling:**
| Key | Action |
|-----|--------|
| **Up** (Press/Repeat) | Scroll up in list |
| **Down** (Press/Repeat) | Scroll down in list |
| **Right** (Short) | Go to BookList |
| **Left** (Press/Short) | Export entire collection as Kindled JSON via NFC text emulation |
| **OK** (Long) | Delete selected passage from collection + save + toast `"Deleted"` |
| **OK** (Short) | Load passage from SD, filter to saved verse range, set `reader_came_from_collection = true`, go to Reader |
| **Back** (Short) | Go to BookList |

**Read from Collection:**
- Loads full chapter from SD, then filters to the saved `start_verse`/`end_verse` range
- Sets `selected_book` and `selected_chapter` to match
- `start_verse`/`end_verse` derived from first/last verse number in filtered result

**Bulk NFC Export (`Left` key):**
- Calls `storage::build_kindled_json(&state.collection)` → in-memory JSON string
- If `nfc_share::start_text_emulation(&json)` succeeds → `NfcShare` view with `nfc_is_export = true`
- If text too large for NTAG215 → toast `"Export too large"`

---

### 4.7 NFC Share (`src/views/nfc_share.rs`)

**Visual Layout:**
- Header: `"NFC Share"` or `"Export NFC"` at y=10
- Divider at y=12
- `"Hold near reader..."` at y=24 with animated pulsing dots (`...` to `....` cycling every 10 frames)
- URL preview (truncated to 28 chars + `"..."`) or `"Export JSON"` at y=38
- `"Back to cancel"` at y=62

**Input Handling:**
| Key | Action |
|-----|--------|
| **Back** (Short) | Stop NFC emulation (`nfc_share::stop_emulation()`), reset `nfc_emitting`/`nfc_url`/`nfc_is_export`, return to Reader or Collection |

---

## 5. Data Formats

### 5.1 SD-Card Chapter Files

**Path:** `/ext/apps_data/kindled_spark/bsb/{osis_lower}/{chapter}.json`

**Example:** `/ext/apps_data/kindled_spark/bsb/jhn/3.json`

**Format (compact JSON, no whitespace):**
```json
{"verses":[{"n":1,"t":"For God so loved..."},{"n":2,"t":"..."}]}
```

| Field | Type | Description |
|-------|------|-------------|
| `verses` | Array | List of verse objects |
| `n` | uint16 | Verse number |
| `t` | string | Verse text (UTF-8) |

**Generation:** `scripts/fetch_bsb.py` downloads `bsb.jsonl` from Arweave and produces ~1,189 chapter files.

### 5.2 Collection File

**Path:** `/ext/apps_data/kindled_spark/collection.json`

**Format:**
```json
{
  "version": "kindled-flipper-v2",
  "passages": [
    {
      "scripture_ref": "JHN.3.16",
      "scripture_display_ref": "John 3:16",
      "scripture_translation": "BSB",
      "book_index": 42,
      "chapter": 3,
      "start_verse": 16,
      "end_verse": 16,
      "captured_at": "2026-01-01T00:00:00Z",
      "note": ""
    }
  ]
}
```

**Write Implementation:** Streaming JSON writer with 512-byte fixed buffer, writes directly to SD file. No large heap allocation. Escapes `"`, `\`, `\n` in strings.

### 5.3 Kindled Export JSON (NFC)

**Format (in-memory, for NFC text export):**
```json
{
  "format": "kindled",
  "version": 1,
  "exported_at": "2026-01-01T00:00:00Z",
  "schema_version": 1,
  "counts": {
    "blocks": N,
    "entities": 0,
    "links": 0,
    "reflections": 0,
    "life_stages": 0
  },
  "data": {
    "blocks": [
      {
        "id": "block-0",
        "type": "scripture",
        "content": "John 3:16",
        "scripture_ref": "JHN.3.16",
        "scripture_display_ref": "John 3:16",
        "scripture_translation": "BSB",
        "scripture_verses": [
          {"number": 16, "text": "For God so loved..."}
        ],
        "source": "manual",
        "captured_at": "2026-01-01T00:00:00Z",
        "modified_at": "2026-01-01T00:00:00Z",
        "tags": []
      }
    ],
    "entities": [],
    "links": [],
    "reflections": [],
    "life_stages": []
  }
}
```

**Note:** For each block, verse text is reloaded from SD card (not stored in `CollectionEntry`). This means the export is always fresh and the collection file stays small.

---

## 6. Canvas & Rendering System

### 6.1 Screen Constants (`src/renderer.rs`)

| Constant | Value | Description |
|----------|-------|-------------|
| `CHAR_WIDTH` | 6 | 5×7 font + 1px gap |
| `CHAR_HEIGHT` | 8 | Pixel height of FontPrimary |
| `LINE_HEIGHT` | 12 | `CHAR_HEIGHT + 4px` inter-line spacing |
| `SCREEN_WIDTH` | 128 | Flipper Zero display width |
| `SCREEN_HEIGHT` | 64 | Flipper Zero display height |
| `MARGIN_X` | 2 | Horizontal text margin |
| `MARGIN_Y` | 2 | Vertical text margin |

### 6.2 Word Wrapping

`wrap_text(text, max_chars)`: Splits text into `Line` chunks by whitespace, respecting `max_chars = (SCREEN_WIDTH - MARGIN_X*2) / CHAR_WIDTH` ≈ 20 chars.

`wrap_verses(verses)`: For each verse:
1. Prefix first wrapped line with `"{verse_number} "`
2. Mark `is_verse_number = true` on first line
3. Set `verse_number` on all lines for that verse

### 6.3 Page Rendering

`render_page(canvas, lines, scroll_offset, y_offset)`:
- Sets `FontPrimary`
- `max_visible = (SCREEN_HEIGHT - y_offset - MARGIN_Y) / LINE_HEIGHT`
- Renders up to `max_visible` lines starting at `scroll_offset`
- Y position: `y_offset + (i * LINE_HEIGHT) + (CHAR_HEIGHT - 1)` baseline offset
- Text copied to a fixed 128-byte null-terminated buffer for `canvas_draw_str`

`total_pages(lines, y_offset)`:
- `max_visible` calculation same as above
- Returns `lines.len().div_ceil(max_visible)` (minimum 1)

### 6.4 Toast System

- `set_toast(msg)` sets message + timer = 60 frames (~2 seconds)
- `tick_toast()` decrements timer each frame; clears at 0
- Rendered as centered black box with white text at y=24–38
- Box width calculated from message length: `(msg_len * 5) + 4`

---

## 7. NFC Sharing System (`src/nfc_share.rs`)

### 7.1 NDEF URL Record Format

**Raw bytes built by `build_ndef_url(url)`:**
```
[NDEF_HEADER=0xD1]  [NDEF_TYPE_LEN=0x01]  [payload_len]  [NDEF_TYPE_URI=0x55]  [URI_PREFIX_HTTPS=0x04]  {url_bytes_without_https://}
```

- `0xD1` = MB=1, ME=1, SR=1, TNF=01 (Well-known type)
- `0x55` = 'U' (URI record type)
- `0x04` = URI prefix: `https://`

### 7.2 NDEF Text Record Format

**Raw bytes built by `build_ndef_text(text)`:**
```
[0xD1] [0x01] [payload_len] [NDEF_TYPE_TEXT=0x54] [0x02] [b'en'] {text_bytes}
```

- `0x54` = 'T' (Text record type)
- `0x02` = UTF-8, language code length = 2

### 7.3 NTAG215 Page Layout

**Page structure (128 pages × 4 bytes = 512 bytes total):**
- Pages 0–2: UID, BCC0, BCC1 (set by `nfc_data_generator_fill_data`)
- Page 3 (CC): Capability Container = `E1 10 12 00`
- Pages 4+: NDEF TLV structure:
  - `0x03` — NDEF Message TLV
  - `{ndef_len}` — 1-byte payload length
  - `{ndef bytes}` — actual NDEF record
  - `0xFE` — Terminator TLV
  - Remaining pages zeroed

**Emulation lifecycle:**
1. `nfc_alloc()` — allocate NFC HAL
2. `nfc_device_alloc()` + `nfc_data_generator_fill_data(NTAG215)` — initialize UID/BCC/CC
3. Get `MfUltralightData` via `nfc_device_get_data`
4. Write NDEF TLV into `page[]` array starting at page 4 (byte 16)
5. `nfc_listener_alloc(nfc, MfUltralight, data)` — create protocol listener
6. `nfc_listener_start(listener, callback, null)` — begin emission
7. `nfc_listener_stop()` + `nfc_listener_free()` + `nfc_device_free()` + `nfc_free()` — cleanup

**Callback:** `nfc_listener_callback` always returns `NfcCommandContinue`.

### 7.4 Legacy `.nfc` File Writer

`write_nfc_file(filename, url)`:
- Writes Flipper-compatible `.nfc` file to `/ext/nfc/{filename}.nfc`
- File format version 3 with NTAG215 device type
- NDEF payload as hex bytes
- After writing, launches the built-in NFC app via `loader_start_with_gui_error("nfc", path)`

**Note:** The `.nfc` file writer is present in the codebase but not actively used by any view — the app uses direct NTAG215 emulation instead.

---

## 8. File I/O & Storage Patterns

### 8.1 SD-Card Paths

| Path | Purpose |
|------|---------|
| `/ext/apps_data/kindled_spark/bsb/{osis}/{chapter}.json` | Chapter verse data |
| `/ext/apps_data/kindled_spark/collection.json` | Saved passages |
| `/ext/nfc/` | Legacy `.nfc` file output directory |

### 8.2 Chunked File Read Pattern (Anti-OOM)

All file reads use the same chunked pattern to avoid heap fragmentation:
```rust
const CHUNK: usize = 1024;
const MAX_FILE_SIZE: usize = 20_000;  // chapter files
let mut buf: Vec<u8> = Vec::new();
let mut chunk = [0u8; CHUNK];
let mut total: usize = 0;
loop {
    let n = storage_file_read(file, chunk.as_mut_ptr(), CHUNK);
    if n == 0 || total + n > MAX_FILE_SIZE { break; }
    buf.extend_from_slice(&chunk[..n]);
    total += n;
}
```

This avoids allocating a single large contiguous block upfront.

### 8.3 Storage Lifecycle Rules (Critical)

Every `storage_file_open` failure path **must** call `storage_file_close()` before `storage_file_free()`. The Flipper firmware crashes if a file is freed without being closed first.

### 8.4 Path-to-C-String Helper

All file paths are converted to null-terminated C strings using a fixed 128-byte buffer:
```rust
fn path_to_cstr(path: &str, buf: &mut [u8; 128]) -> Option<*const c_char>
```

---

## 9. URL Building (`src/route_url.rs`)

**Base:** `https://route.bible`
**Default translation:** `BSB`
**Source tag:** `kindled_spark`

**URL format:**
- Single verse: `/{book_lower}.{chapter}.{verse}?v=BSB&src=kindled_spark`
- Range: `/{book_lower}.{chapter}.{start}-{book_lower}.{chapter}.{end}?v=BSB&src=kindled_spark`

**Example:** `https://route.bible/jhn.3.16?v=BSB&src=kindled_spark`

---

## 10. Bible Metadata (`src/books.rs`)

### 10.1 Static Arrays (66 books each)

| Array | Content |
|-------|---------|
| `OSIS_BOOK_CODES` | `["GEN", "EXO", ..., "REV"]` |
| `OSIS_BOOK_NAMES` | `["Genesis", "Exodus", ..., "Revelation"]` |
| `BOOK_CHAPTER_COUNTS` | Chapter count per book (e.g., Psalms = 150, Revelation = 22) |

### 10.2 Max Verse Tables

Hardcoded per-chapter verse counts for:
- **Genesis**: chapters 1–10 (fallback 30)
- **Psalms**: all 150 chapters via const array `PSA: [u8; 150]`
- **John**: all 21 chapters (fallback 20)
- **Default**: 40 verses

### 10.3 Testament Split

`OT_COUNT = 39` — Malachi (index 38) is the last Old Testament book. Matthew (index 39) starts the New Testament.

---

## 11. Memory Management Patterns

### 11.1 Heap Fragmentation Avoidance

The app is designed for Flipper Zero's ~16–32KB free heap:

1. **No large pre-allocated buffers**: `MAX_FILE_SIZE = 20_000` (actual largest chapter ~15KB), not 64KB
2. **Chunked reads**: 1KB chunks via `extend_from_slice`
3. **Streaming JSON writer**: 512-byte fixed buffer for writes, no `String::with_capacity(8192)` for collection file
4. **No duplicate verse storage**: `Passage` does NOT store `verses: Vec<Verse>`; verses reload from SD on demand
5. **Defragmentation before big allocs**: Before `load_collection()`, `state.lines.clear()` frees scattered String chunks

### 11.2 Stack Size Limits

- `fap_guard.py` enforces `MAX_STACK_ARRAY_BYTES = 1024`
- No stack arrays larger than 1KB allowed

---

## 12. Event Loop Architecture (`src/main.rs`)

```
1. Allocate message queue (8 slots, InputEvent-sized)
2. Allocate AppState on stack
3. Allocate view_port
4. Set draw_callback (receives &AppState)
5. Set input_callback (puts events into message queue)
6. Open "gui" record, add view_port as Fullscreen
7. Loop:
   a. Poll message queue with 100ms timeout
   b. If event received and type is Press/Repeat/Short/Long:
      - Convert to InputEvent
      - Call views::handle_input()
      - If returns true → break (quit)
   c. state.tick_toast()
   d. view_port_update()
8. Cleanup: disable view_port, remove from GUI, free view_port, free queue
```

**Supported Input Types:**
- `InputTypePress` — initial key press
- `InputTypeRepeat` — held key repeat
- `InputTypeShort` — short press release
- `InputTypeLong` — long press release (used for quick-save in Reader)

---

## 13. Navigation Flow Map

```
[App Launch] → BookList

BookList ──Left──► Collection
BookList ──Right──► BookFilter
BookList ──OK────► ChapterList
BookList ──Back──► Quit (if filter=All) or Reset filter

BookFilter ──Left(from All)──► BookList
BookFilter ──OK/Back────────► BookList (apply filter)

ChapterList ──Back──► BookList
ChapterList ──OK────► VerseSelect

VerseSelect ──Back──► ChapterList
VerseSelect ──OK────► Reader (load chapter)

Reader ──Back────────────────────► VerseSelect (or Collection if came_from_collection)
Reader ──OK(short)──────────────► ActionMenu
Reader ──OK(long)───────────────► [Save to collection] → toast → stay in Reader

ActionMenu ──Back────► Reader
ActionMenu ──Save────► [Save] → toast → Reader
ActionMenu ──Share────► NfcShare (URL emission)
ActionMenu ──Back item─► Reader

NfcShare ──Back────► Reader (or Collection if export)

Collection ──Right──► BookList
Collection ──Left───► NfcShare (bulk JSON export)
Collection ──OK─────► Reader (load saved passage)
Collection ──Back───► BookList
```

---

## 14. Dependencies (`Cargo.toml`)

| Crate | Version | Purpose |
|-------|---------|---------|
| `flipperzero-alloc` | 0.16.0 | Heap allocator (wraps Flipper's `furi_alloc`) |
| `flipperzero-sys` | 0.16.0 | Raw FFI bindings to Flipper firmware C APIs |
| `flipperzero-rt` | 0.16.0 | Runtime: `rt::manifest!`, `rt::entry!`, linker script integration |

**Release Profile:**
- `opt-level = "z"` (size optimization)
- `lto = true` (link-time optimization)
- `codegen-units = 1` (single codegen unit)
- `panic = "abort"` (no unwinding)

---

## 15. Text Sanitization (`src/bsb_loader.rs`)

During JSON verse extraction, these Unicode characters are replaced with ASCII equivalents:

| Original | Replacement |
|----------|-------------|
| `—` (em dash) | `-` |
| `'` (right single quote) | `'` |
| `'` (left single quote) | `'` |
| `"` (left double quote) | `"` |
| `"` (right double quote) | `"` |

**Truncation:** Verse text truncated to 512 characters max.

---

## 16. Complete Input Mapping Summary

| Screen | Up | Down | Left | Right | OK (Short) | OK (Long) | Back (Short) |
|--------|----|------|------|-------|------------|-----------|--------------|
| **BookList** | Scroll up | Scroll down | → Collection | → BookFilter | → ChapterList | — | Reset filter / Quit |
| **BookFilter** | Row up | Row down | → BookList (from All) | Move right | → BookList | — | → BookList |
| **ChapterList** | -5 ch | +5 ch | -1 ch | +1 ch | → VerseSelect | — | → BookList |
| **VerseSelect** | Mode up | Mode down | Dec verse | Inc verse | → Reader | — | → ChapterList |
| **Reader** | Prev verse | Next verse | Scroll -1 | Scroll +1 | → ActionMenu | Quick Save | → VerseSelect/Collection |
| **ActionMenu** | Sel up | Sel down | — | — | Execute | — | → Reader |
| **Collection** | Scroll up | Scroll down | → NFC Export | → BookList | → Reader | Delete | → BookList |
| **NfcShare** | — | — | — | — | — | — | Stop NFC → Reader/Collection |

---

## 17. Things to Replicate Precisely in C

1. **All 8 view states** with exact enum values
2. **AppState struct layout** — every field matters for state persistence
3. **Canvas layout constants** — 128×64 screen, `LINE_HEIGHT=12`, header at y=8/10, content at y=16
4. **Chunked file read pattern** — 1KB chunks, 20KB max for chapters, 16KB max for collection
5. **Streaming JSON writer** — 512-byte buffer, direct to file, escape `"\\n`
6. **Minimal JSON parser** — byte-scanner for `"n":` and `"t":"` pairs, no JSON library
7. **Collection JSON schema** — exact field names and structure for compatibility
8. **NTAG215 NDEF layout** — pages 0-3 system, page 4+ TLV, `E1 10 12 00` CC
9. **Route.bible URL format** — exact path and query parameter structure
10. **Heap defragmentation** — clear `lines` before loading collection
11. **Input event filtering** — only process Press, Repeat, Short, Long; ignore Release
12. **Toast system** — 60-frame timer, centered black box, white text
13. **Word wrap algorithm** — split on whitespace, prefix verse number to first line
14. **Page indicator** — `current/total` at bottom-right
15. **Scroll indicator** — 2px-wide thumb on right edge
16. **Book/chapter/verse metadata** — all 66 books, chapter counts, Psalm verse counts, John verse counts
