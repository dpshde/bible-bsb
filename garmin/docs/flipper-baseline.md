# Flipper Zero `bible_bsb` baseline

Source of truth for the Garmin spike. All paths are under `bible_bsb/` unless noted. Flipper screen is **128×64** monochrome (`BIBLE_SCREEN_WIDTH/HEIGHT` in `bible_renderer.h:15-16`).

## Scenes / views (8)

| ID | Enum | Files | Purpose |
|----|------|-------|---------|
| 0 | `BibleSceneBookList` | `bible_view_book_list.c` | Filtered book list (entry) |
| 1 | `BibleSceneBookFilter` | `bible_view_book_filter.c` | 5-col letter grid filter |
| 2 | `BibleSceneChapterList` | `bible_view_chapter_list.c` | 5-col chapter number grid |
| 3 | `BibleSceneVerseSelect` | `bible_view_verse_select.c` | All / Start / End verse picker |
| 4 | `BibleSceneReader` | `bible_view_reader.c` | Paginated scripture reader |
| 5 | `BibleSceneActionMenu` | `bible_view_action_menu.c` | Save / NFC share / back |
| 6 | `BibleSceneCollection` | `bible_view_collection.c` | Saved passages list |
| 7 | `BibleSceneNfcShare` | `bible_view_nfc_share.c` | NFC emit UI |

Scene wiring: `bible_app.h:13-23`, handlers in `bible_app.c:55-329`, registration in `bible_app.c:514-553`. Entry scene is BookList (`bible_app.c:582`).

## Input model (Flipper keys)

Keys: Up, Down, Left, Right, OK, Back. Event types used: `Press`, `Repeat`, `Short`, `Long` (Release ignored). Pattern in every view input callback, e.g. `bible_view_book_list.c:107-111`.

### BookList (`bible_view_book_list.c:103-198`)

| Control | Type | Action |
|---------|------|--------|
| Up / Down | Press/Repeat | Move selection in filtered list; wrap; auto-scroll viewport |
| Left | Short | → Collection |
| Right | Short | → BookFilter |
| OK | Short | → ChapterList (chapter reset to 1) |
| Back | Short | If filter ≠ All: reset filter; else quit app (`bible_app.c:66-81`) |

Missing pack: OK retries presence check; Back exits (`:113-121`).

### BookFilter (`bible_view_book_filter.c:83-154`)

5 columns × up to 3 visible rows; 22 options (`All` + letters). D-pad moves in the grid; Left on index 0 returns to BookList; OK applies filter and returns.

### ChapterList (`bible_view_chapter_list.c:89-155`)

**5-column grid**, cell 24×14, max 3 visible rows (`:10-14`). Index math: `chapter = row*5 + col + 1` (`:48`). Selected row scrolls into view (`:40-43`).

| Control | Type | Action |
|---------|------|--------|
| Up / Down | Press/Repeat | ±5 chapters (one row); clamp to max |
| Left / Right | Press/Repeat | ±1 chapter; clamp |
| OK | Short | → VerseSelect (mode=All) |
| Back | Short | → BookList |

No wrap at ends. Scroll thumb on right edge when rows > 3 (`:76-83`).

### VerseSelect (`bible_view_verse_select.c:82-193`)

Modes 0=All, 1=Start, 2=End. Up/Down change mode; Left/Right adjust verse numbers when in Start/End. OK loads chapter into reader via `bible_load_chapter` (`:166-184`).

### Reader (`bible_view_reader.c:172-256`)

| Control | Type | Action |
|---------|------|--------|
| Up / Down | Press/Repeat | **Verse scroll** — jump to prev/next verse first line |
| Left / Right | Press/Repeat | **Incremental scroll** — ±1 wrapped display line |
| OK | Short | → ActionMenu |
| OK | **Long** | Quick save passage (`bible_save_passage`) |
| Back | Short | → VerseSelect, or Collection if entered from there |

Header: passage ref (`FontSecondary`); page `n/m` bottom-right; toast overlay. Layout: header y=8, divider y=10, content y=16 (`:12-14`). **No chapter continuation** — reader stays inside the loaded passage only.

#### Reader scroll modes (both always live — no toggle)

Flipper does **not** have a scroll-mode toggle, persistence flag, or on-screen mode indicator. Dylan’s two loved modes are bound to **orthogonal axes at the same time** (`bible_view_reader.h:18`, implementation `bible_view_reader.c:193-230`):

1. **Verse scroll (Up/Down)**  
   - `reader_next_verse_offset` / `reader_prev_verse_offset` (`bible_view_reader.c:56-103`).  
   - Uses `BibleLine.verse_number` + `is_verse_number` (first wrapped line of a verse).  
   - Down: find first line whose `verse_number` is greater than the verse at `scroll_offset`; clamp so the new offset ≤ `max_scroll` (`line_count - visible`).  
   - Up: if not already on a verse’s first line, snap to that verse’s first line; else snap to previous verse’s first line; at start → offset 0.  
   - Event types: `InputTypePress` and `InputTypeRepeat` (held key repeats).

2. **Incremental scroll (Left/Right)**  
   - Left: `scroll_offset -= 1` if `> 0`.  
   - Right: `scroll_offset += 1` if `< max_scroll`.  
   - One **wrapped text line** per action (the unit is a `BibleLine` row, not a raw verse).  
   - Same Press/Repeat events.

**Persistence:** none — there is no mode enum in `BibleAppState` (`bible_state.h:96-134`). Only `scroll_offset` (first visible line index) is stored in RAM for the session; it is not written to `collection.json`.

**Boundary behavior on Flipper:** both modes stop at the loaded passage’s first/last lines (`max_scroll`). They do not load adjacent chapters.

Reference screenshots in-repo: `bible_bsb/screenshots/reader.png` (also `screenshots/reader.png`). Copied for Garmin side-by-side review to `garmin/docs/screens/flipper-reference/{books,chapters,reader,verses}.png`.

### ActionMenu (`bible_view_action_menu.c:57-125`)

Items: Save to collection / Share via NFC / Back to reading. Up/Down clamp (no wrap). OK runs item; Back returns.

### Collection (“favorites” on Flipper) (`bible_view_collection.c:88-199`)

Flipper calls this **Collection**, not favorites. Max **100** entries (`bible_state.h:15`). Path: `/ext/apps_data/bible_bsb/collection.json` (`bible_storage.c:12`).

| Control | Type | Action |
|---------|------|--------|
| Up / Down | Press/Repeat | Move selection |
| Right | Short | → BookList |
| Left | Press/Short | NFC bulk export |
| OK | Short | Load entry → Reader |
| OK | **Long** | Delete entry + persist |
| Back | Short | → BookList |

Save flow (`bible_storage.c:513-592`): defrag lines → load collection → duplicate check (`Already saved`) → append → write → reload lines → toast `Saved!` / `Save failed` / `Collection full` / `OOM`.

## BSB text storage / encoding / index

- Bundled pack: `assets/bsb.pack` → installed `/ext/apps_assets/bible_bsb/bsb.pack` (`bible_loader.h:17-19`).
- Format (`bible_pack.h:10-27`): magic `BSB1`, little-endian header 12 bytes, then `count` records of 10 bytes `(book, chapter, comp_size, raw_size, data_offset)`, payloads are **heatshrink** (window_sz2=11, lookahead_sz2=4 per `scripts/fetch_bsb.py:115-116`).
- Lookup: binary search on `(book, chapter)` (`bible_pack.c:51-70`).
- Decode one chapter ≤ **20 000** bytes (`BIBLE_MAX_FILE_SIZE`, `bible_state.h:18`); parse `"n":N,"t":"..."` incrementally; only wrapped `BibleLine`s kept in RAM (`bible_loader.h:20-23`).
- Measured pack (this repo): **2 257 626** bytes, **1189** chapters, ~4.35 MB raw JSON, ~51.6% compressed. Largest chapter: Psalms 119 ≈ 15 052 raw / 6182 compressed. John 3 ≈ 4435 raw / 2243 compressed.

## Book metadata / sizes

- 66 books, OT indices 0–38, NT 39–65 (`bible_books.h:12-13`).
- Chapter counts in `BOOK_CHAPTER_COUNTS` (`bible_books.c:100-104`); Psalms = 150.
- Lines: max 800 (`bible_state.h:17`); verse max 176 (Ps 119).
- Collection JSON load buffer 2 048; read chunk 1 024 (`bible_state.h:19-20`).
- Display wrap: 6px char width → ~20 chars/line (`bible_renderer.h:12-21`); `LINE_HEIGHT` 12.

## Features **not** ported as-is to Garmin spike

NFC share / Kindled export, letter book filter grid (Garmin may use OT/NT split instead), Flipper-specific heap grow helpers. Collection → renamed **bookmarks** on Garmin (see SPEC).
