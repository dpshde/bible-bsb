#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "bible_state.h"

/**
 * Load a chapter from SD card, optionally filtering to a verse range.
 *
 * Reads the chapter JSON file at /ext/apps_data/kindled_spark/bsb/{osis}/{chapter}.json
 * using 1KB chunked reads (max 20KB). Extracts verse number (n) and text (t) pairs
 * via a minimal byte-scanner. Applies text sanitization and 512-char truncation.
 *
 * If start_verse > 0, only verses in [start_verse, end_verse] are retained.
 *
 * @param book_index   0-65 book index
 * @param chapter      1-150 chapter number
 * @param start_verse  0 = all verses, otherwise start of range
 * @param end_verse    0 = all verses, otherwise end of range (inclusive)
 * @param out_passage  output passage struct (caller-allocated, zeroed before call)
 * @return true if at least one verse was loaded
 */
bool bible_load_chapter(
    uint8_t book_index,
    uint16_t chapter,
    uint16_t start_verse,
    uint16_t end_verse,
    BiblePassage* out_passage);
