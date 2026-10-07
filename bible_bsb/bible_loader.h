#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "bible_state.h"

/**
 * True when Genesis 1 is on the SD card.
 * The app treats that file as the signal that the chapter pack is installed.
 */
bool bible_chapter_data_present(void);

/**
 * Load a chapter from SD card into display lines, optionally filtering to a verse range.
 *
 * Reads APP_DATA_PATH("bsb/<osis>/<chapter>.json"), which is
 * /ext/apps_data/bible_bsb/bsb/<osis>/<chapter>.json on the SD card,
 * using 1KB chunked reads (max 20KB). Extracts verse number (n) and text (t) pairs
 * via a minimal byte-scanner. Parses ONE verse at a time: sanitizes its text,
 * wraps it into BibleLine entries appended to state->lines, then discards the text.
 * No verse texts are retained in RAM. Only the wrapped display lines are kept.
 *
 * If start_verse > 0, only verses in [start_verse, end_verse] are retained.
 * A missing file sets state->show_data_help.
 *
 * @param book_index   0-65 book index
 * @param chapter      1-150 chapter number
 * @param start_verse  0 = all verses, otherwise start of range
 * @param end_verse    0 = all verses, otherwise end of range (inclusive)
 * @param state        app state (lines and passage are updated in-place)
 * @return true if at least one line was produced
 */
bool bible_load_chapter(
    uint8_t book_index,
    uint16_t chapter,
    uint16_t start_verse,
    uint16_t end_verse,
    BibleAppState* state);

/**
 * Scan a chapter JSON file on SD and emit each verse via a callback.
 *
 * Used by build_kindled_json to stream verse text without storing all verses in RAM.
 * Opens the file, reads it in 1KB chunks into a local buffer (max 20KB),
 * then scans for "n":N,"t":"..." pairs and invokes the callback for each.
 *
 * @param book_index   0-65 book index
 * @param chapter      1-150 chapter number
 * @param start_verse  0 = all verses, otherwise start of range
 * @param end_verse    0 = all verses, otherwise end of range (inclusive)
 * @param callback     called for each matching verse; return false to stop scanning
 * @param ctx          opaque pointer passed to callback
 * @return true if file was opened and scanned (false = file not found or OOM)
 */
typedef bool (*BibleVerseCallback)(uint16_t verse_num, const char* text, void* ctx);

bool bible_load_chapter_verse_scan(
    uint8_t book_index,
    uint16_t chapter,
    uint16_t start_verse,
    uint16_t end_verse,
    BibleVerseCallback callback,
    void* ctx);
