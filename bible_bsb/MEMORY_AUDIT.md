# Bible [BSB] C App — Comprehensive Memory Audit Report

**Date:** 2026-05-17
**Auditor:** Worker subagent
**Scope:** All `.c` and `.h` files in `/home/dpshade/Developer/kindled-flipper/bible_bsb/`
**Target platform:** Flipper Zero (Cortex-M4, thumbv7em-none-eabihf)
**Constraints:** ~16–32 KB FAP heap, 4 KB app stack (`stack_size=4*1024` in `application.fam`)

---

## Executive Summary

The app’s **startup heap footprint** (before the BookList is visible) is approximately **2.6–3.0 KB** of combined app + firmware allocations. This is normally survivable on a 16 KB heap, but the app contains **one catastrophic heap allocation** and **multiple high-risk stack frames** that together explain the "out of memory" crashes.

| Severity | Count | Top issues |
|----------|-------|------------|
| **CRITICAL** | 2 | 90 KB verse array allocation; unchecked `bible_lines_ensure` / `bible_collection_ensure` return values |
| **HIGH** | 4 | Deep stack nesting during NFC export (~3.3 KB); unchecked `malloc` return values in firmware wrappers; large stack buffers in loader |
| **MEDIUM** | 5 | Stack waste (`export_buf[1024]` when 512 suffices); `realloc` without clearing stale pointers on failure; stale collection entry data after rollback |
| **LOW** | 3 | Minor stack usage in draw callbacks; static NFC emulation state; harmless const data in RAM |

---

## 1. Struct Sizes (32-bit ARM EABI)

| Struct | Estimated bytes | Notes |
|--------|-----------------|-------|
| `BibleLine` | **68** | `text[64]` + `verse_number` (2) + `bool` (1) + padding (1) |
| `BibleVerse` | **514** | `number` (2) + `text[512]` — the 512-byte text field is the dominant cost |
| `BiblePassage` | **16** | 1+1 pad + 2+2+2+2 + `verses*` (4); 4-byte aligned |
| `BibleCollectionEntry` | **176** | Two 32-char strings + 8-char + 32-char + 64-char + 3×uint16 + uint8 + padding |
| `BibleToast` | **68** | `message[64]` + `timer` (1) + 3-byte pad |
| `BibleAppState` | **~260–376** | Depends on compiler padding; previous fix targeted ~376 B |
| `BibleApp` | **~48** | 3 pointers + `state*` + `views[8]` |
| `JsonWriter` | **~524** | `buf[512]` + `File*` + `pos` + `total_written` + `failed` + padding |
| `EmulationState` | **~16** | 3 pointers + `bool` + 3-byte pad (static global in `.bss`) |

**Key insight:** `BibleVerse` at 514 bytes means **every loaded verse costs half a kilobyte**. A 30-verse chapter allocates ~15 KB. Psalms 119 (176 verses) triggers a **single 90 KB `malloc`** — guaranteed fatal on this platform.

---

## 2. Startup Memory Footprint (`bible_app_alloc`)

`bible_app_alloc()` (`bible_app.c`, lines ~288–375) allocates everything before the first frame:

### App-controlled heap

| Allocation | Line | Size | Freed in | Risk |
|------------|------|------|----------|------|
| `malloc(sizeof(BibleApp))` | ~289 | ~48 B | `bible_app_free` | **LOW** — checked via `furi_check` |
| `malloc(sizeof(BibleAppState))` | ~292 | ~260–376 B | `bible_app_free` → `bible_app_state_deinit` | **LOW** — checked via `furi_check` |
| `view_dispatcher_alloc()` | ~296 | **~300–600 B** (firmware internal) | `view_dispatcher_free` | **MEDIUM** — no NULL check |
| `scene_manager_alloc(...)` | ~297 | **~200–400 B** (firmware internal) | `scene_manager_free` | **MEDIUM** — no NULL check |
| `furi_record_open(RECORD_GUI)` | ~305 | shared system handle | `furi_record_close` | **LOW** — not app-owned |
| `view_alloc()` × 8 | ~312–369 | **~100–300 B each** (firmware internal) | `view_free` × 8 | **HIGH** — no NULL checks; 8× |

**Startup total (app heap):** ~308 B  
**Startup total (firmware heap on app’s behalf):** ~1.5–3.0 KB  
**Combined startup footprint:** **~2.0–3.5 KB**

### Risk: Unchecked firmware allocator returns

Every `view_alloc()`, `view_dispatcher_alloc()`, and `scene_manager_alloc()` return value is stored directly without a NULL check. On a fragmented heap, any one of these 10 calls can return NULL, leading to a null-pointer dereference on the next `view_set_draw_callback()` or `view_dispatcher_add_view()`.  
**→ Risk: HIGH** (10 unchecked allocation sites)

---

## 3. Heap Allocations — File by File

### 3.1 `bible_app.c`

| Location | Type | Size | Free path | Risk | Notes |
|----------|------|------|-----------|------|-------|
| `bible_app_alloc` l.289 | `malloc(sizeof(BibleApp))` | ~48 B | `bible_app_free` l.384 | LOW | `furi_check(app)` panics on NULL |
| `bible_app_alloc` l.292 | `malloc(sizeof(BibleAppState))` | ~260–376 B | `bible_app_free` → `bible_app_state_deinit` l.400 | LOW | `furi_check(app->state)` panics on NULL |
| `bible_app_alloc` l.296 | `view_dispatcher_alloc()` | ~300–600 B | `view_dispatcher_free` l.408 | HIGH | **No NULL check** |
| `bible_app_alloc` l.297 | `scene_manager_alloc(...)` | ~200–400 B | `scene_manager_free` l.409 | HIGH | **No NULL check** |
| `bible_app_alloc` l.312–369 | `view_alloc()` × 8 | ~800–2400 B total | `view_free` × 8 l.390–397 | HIGH | **No NULL checks on any** |

### 3.2 `bible_loader.c`

| Location | Type | Size | Free path | Risk | Notes |
|----------|------|------|-----------|------|-------|
| `bible_load_chapter` l.~143 | `realloc(buf, new_cap + 1)` | grows to **max 20,001 B** | `free(buf)` l.~174 | MEDIUM | Chunked 1 KB reads; safe pattern, but `new_buf` break leaves `buf` intact |
| `bible_load_chapter` l.~186 | `malloc(verse_count * sizeof(BibleVerse))` | **up to 90,464 B** | `bible_passage_free_verses()` | **CRITICAL** | 176 verses × 514 B = 90 KB single block. Even 30 verses = 15 KB. Guaranteed OOM on large chapters or fragmented heap. |

**CRITICAL FINDING — 90 KB verse allocation:**

- **File:** `bible_loader.c`
- **Line:** ~186 (inside `bible_load_chapter`)
- **Code:** `out_passage->verses = malloc(verse_count * sizeof(BibleVerse));`
- **Maximum size:** 176 × 514 = **90,464 bytes** (Psalms 119)
- **Typical size:** 30 × 514 = **15,420 bytes** (average chapter)
- **Why it crashes:** The Flipper heap is 16–32 KB *total*. A single 15 KB contiguous block often fails due to fragmentation. A 90 KB request is impossible. The crash is almost certainly happening here when the user selects any chapter with >20 verses.
- **Recommendation:** Do NOT store full 512-byte verse text in RAM. Keep verses on SD and stream them, or store only display lines (which are already 68 B each, max 512 × 68 = 34 KB — still large but smaller than 90 KB). Alternatively, cap verse text to a smaller inline buffer (e.g., 128 B) and truncate, or read verse text on-demand per page.

### 3.3 `bible_state.h` (inline helpers)

| Location | Type | Size | Free path | Risk | Notes |
|----------|------|------|-----------|------|-------|
| `bible_lines_ensure` l.~111 | `realloc(state->lines, new_cap * sizeof(BibleLine))` | grows by ~1 KB per call; max 512 × 68 = **34,816 B** | `bible_lines_free` → `free(state->lines)` | MEDIUM | Grows incrementally (15 lines ≈ 1 KB). Safe pattern. |
| `bible_collection_ensure` l.~137 | `realloc(state->collection, new_cap * sizeof(BibleCollectionEntry))` | doubles; max 100 × 176 = **17,600 B** | `bible_collection_free` → `free(state->collection)` | MEDIUM | Grows from 8 → 16 → 32 → 64 → 100. Safe pattern. |

**Issue — unchecked return values in callers:**

`bible_lines_ensure()` returns `bool`, but the return value is **ignored** in multiple locations:
- `bible_view_verse_select.c` l.~184: `bible_lines_ensure(state, BIBLE_MAX_LINES);` — return discarded
- `bible_storage.c` `bible_storage_load_verses_for_entry` l.~312: return discarded
- `bible_storage.c` `bible_save_passage` l.~288, ~306, ~330: return discarded in all three call sites

If `realloc` fails, `state->lines` may be NULL or point to freed memory. The code then proceeds to `bible_wrap_verses()` which writes through the invalid pointer → **BusFault / HardFault**.

**→ Risk: CRITICAL** (4 unchecked call sites)

Similarly, `bible_collection_ensure()` return value IS checked in `bible_save_passage` (good), but should be checked everywhere consistently.

### 3.4 `bible_storage.c`

| Location | Type | Size | Free path | Risk | Notes |
|----------|------|------|-----------|------|-------|
| `bible_storage_load_collection` l.~145 | `realloc(buf, new_cap + 1)` | max **2,049 B** | `free(buf)` l.~187 | LOW | Same chunked pattern as loader. Safe. |
| `bible_storage_build_kindled_json` | `bible_load_chapter` (indirect) | up to 90 KB | `bible_passage_free_verses` inside loop | **CRITICAL** | Reloads every collection entry from SD. Each call can allocate up to 90 KB. |

**Note on `bible_storage_build_kindled_json`:** This function saves `state->passage` to a local `saved_passage`, uses `state->passage` as scratch for each entry, then restores. The save/restore of the `verses` pointer is correct (no double-free). However, if `bible_load_chapter` fails mid-loop, `state->passage.verses` is NULL, and the loop continues. This is safe because `bible_passage_free_verses` checks for NULL.

### 3.5 `bible_nfc.c`

| Location | Type | Size | Free path | Risk | Notes |
|----------|------|------|-----------|------|-------|
| `start_ndef_emulation` l.~142 | `nfc_alloc()` | firmware internal | `nfc_free` | MEDIUM | No NULL check before storing to `emulation_state.nfc` |
| `start_ndef_emulation` l.~148 | `nfc_device_alloc()` | firmware internal | `nfc_device_free` | MEDIUM | Checked, but cleanup on failure is manual and scattered |
| `start_ndef_emulation` l.~170 | `nfc_listener_alloc(...)` | firmware internal | `nfc_listener_free` | MEDIUM | Checked; partial cleanup on failure is correct but verbose |

The NFC emulation state is stored in a `static EmulationState emulation_state` (~16 B in `.bss`). This persists across app restarts if the firmware does not zero `.bss` on FAP reload. The `bible_nfc_stop` cleanup is thorough and correctly handles `state == NULL`.

---

## 4. Stack Allocations — File by File

### 4.1 `bible_loader.c` — Chapter loading (heaviest stack user)

| Variable | Line | Size | Context | Risk |
|----------|------|------|---------|------|
| `path[128]` | ~118 | 128 B | `bible_load_chapter` | MEDIUM |
| `chunk[1024]` | ~141 | 1,024 B | `bible_load_chapter` | HIGH |
| `text_buf[512]` | ~65 | 512 B | `bible_parse_verses` (called from loader) | HIGH |

**Total stack in `bible_load_chapter` frame:** ~1,664 B  
**Percentage of 4 KB stack:** ~41%  

This is the single heaviest stack frame in the app. Combined with caller frames (e.g., input handler ~200 B) and `bible_parse_verses` (~160 B), a chapter load consumes **~2,000–2,200 B** of stack.

### 4.2 `bible_storage.c` — Collection operations

| Variable | Line | Size | Context | Risk |
|----------|------|------|---------|------|
| `JsonWriter w` (contains `buf[512]`) | ~75 | ~524 B | `bible_storage_save_collection` | MEDIUM |
| `chunk[1024]` | ~137 | 1,024 B | `bible_storage_load_collection` | HIGH |
| `block_buf[256]` | ~365 | 256 B | `bible_storage_build_kindled_json` | MEDIUM |
| `num_buf[8]` | ~367 | 8 B | `bible_storage_build_kindled_json` | LOW |
| `BiblePassage saved_passage` | ~349 | ~16 B | `bible_storage_build_kindled_json` | LOW |

**Total stack in `bible_storage_load_collection` frame:** ~1,100 B  
**Total stack in `bible_storage_build_kindled_json` frame:** ~300 B

### 4.3 `bible_view_collection.c` — NFC export

| Variable | Line | Size | Context | Risk |
|----------|------|------|---------|------|
| `export_buf[1024]` | ~115 | 1,024 B | `bible_bsb_view_collection_input` (Left key handler) | **HIGH** |

This buffer is used for NFC JSON export. The comment says "NTAG215 has ~500 bytes for payload", yet the buffer is 1024 B — **double what's needed**. Reducing to 512 B would save 512 B of stack.

### 4.4 `bible_nfc.c` — NFC stack buffers

| Variable | Line | Size | Context | Risk |
|----------|------|------|---------|------|
| `ndef[256]` | ~233 | 256 B | `bible_nfc_start_url` | MEDIUM |
| `ndef[512]` | ~248 | 512 B | `bible_nfc_start_text` | HIGH |

When `bible_nfc_start_text` is called from `bible_view_collection_input` (which already has `export_buf[1024]`), the combined stack buffers are **1,536 B** before counting call frames.

### 4.5 `bible_renderer.c` — Word wrap

| Variable | Line | Size | Context | Risk |
|----------|------|------|---------|------|
| `prefix[8]` | ~24 | 8 B | `bible_word_wrap` | LOW |
| `current[64]` | ~32 | 64 B | `bible_word_wrap` | LOW |
| `word[64]` | ~36 | 64 B | `bible_word_wrap` | LOW |

Total ~136 B — acceptable.

### 4.6 Draw / input callbacks (all views)

| File | Variable | Size | Context | Risk |
|------|----------|------|---------|------|
| `bible_view_book_list.c` | `filtered[BIBLE_BOOK_COUNT]` (66 B) + `header[16]` (16 B) + locals | ~120 B | draw + input | LOW |
| `bible_view_book_filter.c` | loop locals only | ~40 B | draw + input | LOW |
| `bible_view_chapter_list.c` | `header` + locals | ~60 B | draw + input | LOW |
| `bible_view_verse_select.c` | `header[48]` + `start_label[32]` + `end_label[32]` + `actual_max` | ~120 B | draw + input | LOW |
| `bible_view_reader.c` | `ref_buf[48]` + `page_str[16]` + locals | ~80 B | draw + input | LOW |
| `bible_view_action_menu.c` | loop locals only | ~40 B | draw + input | LOW |
| `bible_view_nfc_share.c` | `preview[48]` + `dots[8]` + locals | ~80 B | draw + input | LOW |
| `bible_view_collection.c` | `export_buf[1024]` (input only) | 1,024 B | input | HIGH |

### 4.7 Critical stack nesting analysis

The deepest stack nesting occurs during **NFC bulk export** from the Collection view:

```
Frame 1: bible_bsb_view_collection_input
         └─ export_buf[1024] + other locals ≈ 1,100 B

    Frame 2: bible_storage_build_kindled_json
             └─ block_buf[256] + saved_passage + num_buf + pos ≈ 320 B

        Frame 3: bible_load_chapter (called once per collection entry)
                 └─ path[128] + chunk[1024] + text_buf[512] + file* + storage* ≈ 1,750 B

            Frame 4: bible_parse_verses
                     └─ prefix[8] + current[64] + word[64] + locals ≈ 160 B
```

**Peak stack usage during NFC export: ~3,330 B / 4,096 B = 81%**

With ISR overhead, timer callbacks, and the ViewDispatcher tick callback running concurrently, this is **extremely likely to overflow the 4 KB stack**, causing a HardFault that looks like an OOM or random crash.

**→ Risk: CRITICAL**

Similarly, normal chapter reading peaks at:
- `verse_select_input` (~200 B) → `bible_load_chapter` (~1,750 B) → `bible_parse_verses` (~160 B) → `bible_wrap_verses` → `bible_word_wrap` (~136 B)  
- **Total: ~2,250 B = 55%** — high but usually survivable.

---

## 5. Potential Double-Frees & Use-After-Free

### 5.1 Double-free

| Location | Analysis | Verdict |
|----------|----------|---------|
| `bible_load_chapter` frees `out_passage->verses` before allocating new ones | `if(out_passage->verses) { free(...); out_passage->verses = NULL; }` | **SAFE** — nulls pointer after free |
| `bible_app_state_deinit` calls `bible_passage_free_verses`, `bible_lines_free`, `bible_collection_free` | Each helper nulls the pointer after free | **SAFE** |
| `bible_storage_build_kindled_json` saves/restores `state->passage` | `saved_passage` is a struct copy (pointer copy). Scratch verses are freed, original pointer restored. | **SAFE** |
| `bible_app_free` frees views, then state, then app | Reverse of alloc order. `view_free` is called after `view_dispatcher_remove_view`. | **SAFE** |

**No confirmed double-free vulnerabilities found.**

### 5.2 Use-after-free

| Location | Analysis | Verdict |
|----------|----------|---------|
| `bible_lines_ensure` / `bible_collection_ensure` callers ignore `false` return | If `realloc` fails and returns NULL, the old pointer may be freed by `realloc` (C standard: if realloc fails, old block is unchanged, but some libc implementations differ). The code stores `new_lines` only on success, so `state->lines` stays valid on failure. | **SAFE** (no UAF) |
| `bible_loader.c` `realloc(buf, ...)` break on failure | `buf` remains the old valid pointer; freed later with `free(buf)` | **SAFE** |

**No confirmed use-after-free vulnerabilities found.**

However, **if `realloc` returns NULL on failure, the caller that ignores `bible_lines_ensure`'s `false` will proceed to dereference `state->lines` which is still valid (old pointer), but may point to insufficient memory. This is not UAF but could cause a buffer overflow in `bible_wrap_verses`.**

---

## 6. Memory Leaks

### 6.1 Confirmed leak: none

All dynamically allocated memory has a corresponding free path:
- `BibleApp` → `bible_app_free`
- `BibleAppState` → `bible_app_free` → `bible_app_state_deinit`
- `verses` → `bible_passage_free_verses`
- `lines` → `bible_lines_free`
- `collection` → `bible_collection_free`
- `buf` (loader) → `free(buf)`
- `buf` (storage load) → `free(buf)`
- NFC resources → `bible_nfc_stop`

### 6.2 Potential leak on abnormal exit

If the app crashes or is killed by the firmware loader, `bible_app_free` is never called. The Flipper firmware may reclaim the FAP's heap on unload, but this is not guaranteed for all firmware builds. In practice, the ufbt/Cargo build pipeline produces a FAP that runs in a sandboxed heap, so process termination should reclaim memory.

### 6.3 Stale data (not a true leak)

In `bible_save_passage` (`bible_storage.c` l.~338), if `bible_storage_save_collection` fails:
```c
state->collection_count--;
```
The last entry's data remains in the `state->collection` array (still owned by `state`). It will be freed when the app exits. Not a leak, but stale data could be read if `collection_count` is ever misused.

---

## 7. Static / Global Data

| Symbol | File | Size | Section | Risk |
|--------|------|------|---------|------|
| `BIBLE_FILTER_LABELS[22]` | `bible_books.c` | 22 pointers (~88 B) | `.rodata` | LOW (flash, not RAM) |
| `OSIS_BOOK_CODES[66]` | `bible_books.c` | 66 pointers (~264 B) | `.rodata` | LOW |
| `OSIS_BOOK_NAMES[66]` | `bible_books.c` | 66 pointers (~264 B) | `.rodata` | LOW |
| `BOOK_CHAPTER_COUNTS[66]` | `bible_books.c` | 66 B | `.rodata` | LOW |
| `GENESIS_MAX_VERSES[10]` | `bible_books.c` | 10 B | `.rodata` | LOW |
| `PSALMS_MAX_VERSES[150]` | `bible_books.c` | 150 B | `.rodata` | LOW |
| `JOHN_MAX_VERSES[21]` | `bible_books.c` | 21 B | `.rodata` | LOW |
| `CHAPTER_NUMS[151]` | `bible_view_chapter_list.c` | 151 pointers (~604 B) | `.rodata` | LOW |
| `emulation_state` | `bible_nfc.c` | ~16 B | `.bss` | LOW |
| Callback arrays (8 scenes) | `bible_app.c` | ~200 B | `.rodata` | LOW |
| `ACTION_MENU_ITEMS[3]` | `bible_view_action_menu.c` | 3 pointers (~12 B) | `.rodata` | LOW |

**Total static/global RAM:** ~16 B (only `emulation_state` lives in `.bss`).  
All const tables are in flash (`.rodata`) and do not consume precious RAM.

---

## 8. ViewDispatcher / SceneManager Internal Allocations

| Call | File | Line | What it allocates (firmware internal) | Estimated size | Risk |
|------|------|------|----------------------------------------|----------------|------|
| `view_dispatcher_alloc()` | `bible_app.c` | 296 | `ViewDispatcher` struct + `FuriMessageQueue` + timer | 300–600 B | HIGH (unchecked) |
| `scene_manager_alloc(...)` | `bible_app.c` | 297 | `SceneManager` + scene state array + stack | 200–400 B | HIGH (unchecked) |
| `view_alloc()` × 8 | `bible_app.c` | 312–369 | `View` struct + `ViewModel` + `FuriMutex` per view | ~100–300 B each | HIGH (unchecked) |
| `view_dispatcher_add_view()` × 8 | `bible_app.c` | 312–369 | Stores view pointer in dispatcher array (no extra alloc) | 0 B | LOW |
| `view_dispatcher_set_tick_event_callback()` | `bible_app.c` | 302 | Registers tick callback in dispatcher | 0 B | LOW |

These are the **largest consumers of heap at startup**. If any one of the 10 allocator calls returns NULL, the app will dereference a null pointer in the next line of code.

---

## 9. Most Critical Findings (Ranked)

### 🔴 CRITICAL #1: 90 KB verse array — guaranteed OOM on large chapters

- **File:** `bible_loader.c`
- **Line:** ~186
- **Code:** `out_passage->verses = malloc(verse_count * sizeof(BibleVerse));`
- **Impact:** Any chapter with >25–30 verses allocates a contiguous block larger than the entire available heap. Psalms 119 (176 verses) needs 90 KB — impossible.
- **Fix:** Reduce `BibleVerse.text` from 512 B to something smaller (e.g., 128 B) and truncate long verses, or eliminate `verses` entirely and stream text from SD per page. The Rust version previously removed `verses` from `Passage` for this exact reason.

### 🔴 CRITICAL #2: Unchecked `bible_lines_ensure` return values

- **Files:** `bible_view_verse_select.c`, `bible_storage.c` (3 locations)
- **Impact:** If `realloc` fails, code proceeds to write display lines through an invalid or undersized buffer → BusFault.
- **Fix:** Check `if(!bible_lines_ensure(state, BIBLE_MAX_LINES)) { bible_toast_set(..., "OOM"); return; }` at every call site.

### 🟠 HIGH #3: Stack overflow during NFC bulk export

- **Files:** `bible_view_collection.c` → `bible_storage.c` → `bible_loader.c`
- **Peak stack:** ~3,330 B / 4,096 B (81%)
- **Fix:** Shrink `export_buf` from 1024 B to 512 B. Move `chunk[1024]` and `text_buf[512]` in `bible_load_chapter` to static buffers or heap. Better: pre-allocate a static 1 KB read buffer (shared across all file reads).

### 🟠 HIGH #4: Large stack frame in chapter loader

- **File:** `bible_loader.c`
- **Stack:** `chunk[1024]` + `text_buf[512]` + `path[128]` = 1,664 B
- **Fix:** Make `chunk` a static global buffer (1 KB, shared) or allocate it on the heap. `text_buf` is inside `bible_parse_verses` — can also be reduced or made static.

### 🟠 HIGH #5: Unchecked `malloc` in firmware wrapper allocations

- **File:** `bible_app.c`
- **Count:** 10 unchecked calls (`view_dispatcher_alloc`, `scene_manager_alloc`, 8× `view_alloc`)
- **Fix:** Wrap each in `if(!x) { bible_app_free_partial(app); return NULL; }`

### 🟡 MEDIUM #6: `bible_collection_ensure` growth strategy

- **File:** `bible_state.h`
- **Code:** `new_cap = state->collection_capacity > 0 ? state->collection_capacity * 2 : 8;`
- **Impact:** Doubling from 8 → 16 → 32 → 64 → 100. The jump from 64 to 100 is actually a shrink (should be 128 but capped by `BIBLE_MAX_COLLECTION`). Not a bug, but the `* 2` strategy can overshoot and waste heap.

### 🟡 MEDIUM #7: Stale collection entry on save rollback

- **File:** `bible_storage.c` `bible_save_passage`
- **Impact:** On save failure, `collection_count--` hides the last entry but its 176 B of data remains in the array until app exit. Minor data leak, not a heap leak.

---

## 10. Recommended Fixes (Priority Order)

1. **Reduce verse text buffer size.** Change `BibleVerse.text[512]` to `text[128]` (or smaller) and truncate verses at the wrap stage. This drops the max verse allocation from 90 KB to ~22 KB (still risky) or ~9 KB at 64 B per verse. Ideally, remove `verses` from RAM entirely and read from SD on demand.

2. **Add NULL/return checks to all allocators.**
   - `bible_app_alloc`: check every `view_alloc()` return
   - `bible_lines_ensure` callers: check return bool
   - `bible_collection_ensure` callers: already checked in most places; audit remaining

3. **Shrink or relocate stack buffers.**
   - `export_buf[1024]` → `export_buf[512]` in `bible_view_collection.c`
   - `chunk[1024]` in `bible_loader.c` → static global `static uint8_t bible_read_chunk[1024];` (shared, no stack cost)
   - `text_buf[512]` in `bible_parse_verses` → static or heap
   - `chunk[1024]` in `bible_storage_load_collection` → static or heap

4. **Add heap-defrag before large allocations.** Before `bible_load_chapter`, clear `state->lines` (free display lines) to reduce heap fragmentation. The save-passage flow already does this — apply the same pattern before chapter loads.

5. **Cap verse count.** Even with smaller text buffers, 176 verses is a lot of metadata. Consider capping loaded verses to a reasonable number (e.g., 50) and showing a "truncated" notice.

---

*End of report.*
