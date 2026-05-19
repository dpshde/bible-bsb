#include "bible_loader.h"
#include "bible_books.h"
#include "bible_renderer.h"

#include <furi.h>
#include <storage/storage.h>
#include <string.h>

/* ============================================================================
 * Chapter loader — single-pass incremental parsing, NO verse array in RAM
 * ============================================================================ */

#define BSB_PATH_PREFIX "/ext/apps_data/kindled_spark/bsb/"

static void bible_sanitize_text(char* text, size_t max_len) {
    size_t len = strlen(text);
    if(len > max_len) {
        text[max_len] = '\0';
        len = max_len;
    }
    for(size_t i = 0; i < len; i++) {
        /* Em dash -> hyphen */
        if((unsigned char)text[i] == 0xE2 && (unsigned char)text[i + 1] == 0x80 &&
           (unsigned char)text[i + 2] == 0x94) {
            text[i] = '-';
            memmove(&text[i + 1], &text[i + 3], len - i - 2);
            len -= 2;
        }
        /* Right single quote -> apostrophe */
        else if(
            (unsigned char)text[i] == 0xE2 && (unsigned char)text[i + 1] == 0x80 &&
            (unsigned char)text[i + 2] == 0x99) {
            text[i] = '\'';
            memmove(&text[i + 1], &text[i + 3], len - i - 2);
            len -= 2;
        }
        /* Left single quote -> apostrophe */
        else if(
            (unsigned char)text[i] == 0xE2 && (unsigned char)text[i + 1] == 0x80 &&
            (unsigned char)text[i + 2] == 0x98) {
            text[i] = '\'';
            memmove(&text[i + 1], &text[i + 3], len - i - 2);
            len -= 2;
        }
        /* Left double quote -> straight quote */
        else if(
            (unsigned char)text[i] == 0xE2 && (unsigned char)text[i + 1] == 0x80 &&
            (unsigned char)text[i + 2] == 0x9C) {
            text[i] = '"';
            memmove(&text[i + 1], &text[i + 3], len - i - 2);
            len -= 2;
        }
        /* Right double quote -> straight quote */
        else if(
            (unsigned char)text[i] == 0xE2 && (unsigned char)text[i + 1] == 0x80 &&
            (unsigned char)text[i + 2] == 0x9D) {
            text[i] = '"';
            memmove(&text[i + 1], &text[i + 3], len - i - 2);
            len -= 2;
        }
    }
}

/* ============================================================================
 * Shared helpers: build path and read file into a heap buffer
 * ============================================================================ */

static bool bible_build_path(uint8_t book_index, uint16_t chapter, char* path, size_t path_len) {
    const char* osis = OSIS_BOOK_CODES[book_index];
    if(osis == NULL || chapter == 0) {
        return false;
    }

    snprintf(path, path_len, BSB_PATH_PREFIX "%s/%u.json", osis, (unsigned int)chapter);

    /* Convert OSIS code to lowercase in-place */
    for(size_t i = strlen(BSB_PATH_PREFIX); path[i] != '/' && path[i] != '\0'; i++) {
        if(path[i] >= 'A' && path[i] <= 'Z') {
            path[i] = path[i] - 'A' + 'a';
        }
    }
    return true;
}

/* Read chapter JSON from SD into a dynamically-grown buffer.
 * Returns true on success; caller must free(*out_buf).
 * Returns false on error; *out_buf is freed automatically.
 */
static bool bible_read_chapter_file(const char* path, uint8_t** out_buf, size_t* out_len) {
    Storage* storage = furi_record_open(RECORD_STORAGE);
    File* file = storage_file_alloc(storage);
    bool ok = storage_file_open(file, path, FSAM_READ, FSOM_OPEN_EXISTING);

    if(!ok) {
        storage_file_close(file);
        storage_file_free(file);
        furi_record_close(RECORD_STORAGE);
        return false;
    }

    uint8_t* buf = NULL;
    size_t total = 0;
    size_t capacity = 0;

    /* Use a static chunk buffer to keep stack usage low */
    static uint8_t chunk[BIBLE_READ_CHUNK];

    while(total < BIBLE_MAX_FILE_SIZE) {
        size_t n = storage_file_read(file, chunk, sizeof(chunk));
        if(n == 0) break;

        if(total + n > BIBLE_MAX_FILE_SIZE) {
            n = BIBLE_MAX_FILE_SIZE - total;
        }

        if(total + n > capacity) {
            size_t new_cap = capacity + BIBLE_READ_CHUNK;
            if(new_cap > BIBLE_MAX_FILE_SIZE) {
                new_cap = BIBLE_MAX_FILE_SIZE;
            }
            uint8_t* new_buf = realloc(buf, new_cap + 1);
            if(!new_buf) break;
            buf = new_buf;
            capacity = new_cap;
        }

        memcpy(buf + total, chunk, n);
        total += n;
    }

    storage_file_close(file);
    storage_file_free(file);
    furi_record_close(RECORD_STORAGE);

    if(total == 0 || buf == NULL) {
        free(buf);
        return false;
    }

    buf[total] = '\0';
    *out_buf = buf;
    *out_len = total;
    return true;
}

/* ============================================================================
 * Incremental JSON verse scanner: calls a callback for each matching verse.
 * Only ONE verse's text is in memory at a time.
 * ============================================================================ */

static bool bible_scan_verses_from_json(
    const char* json,
    size_t json_len,
    uint16_t start_verse,
    uint16_t end_verse,
    BibleVerseCallback callback,
    void* ctx) {
    const char* p = json;
    uint16_t count = 0;

    while(*p != '\0') {
        /* Look for "n": */
        size_t offset = (size_t)(p - json);
        if(offset + 4 > json_len) break;

        if(*p == '"' && *(p + 1) == 'n' && *(p + 2) == '"' && *(p + 3) == ':') {
            p += 4;
            while(*p == ' ' || *p == '\t')
                p++;

            uint16_t verse_num = 0;
            while(*p >= '0' && *p <= '9') {
                verse_num = verse_num * 10 + (*p - '0');
                p++;
            }

            /* Look for "t":" */
            while(*p != '\0') {
                offset = (size_t)(p - json);
                if(offset + 5 > json_len) break;

                if(*p == '"' && *(p + 1) == 't' && *(p + 2) == '"' && *(p + 3) == ':' &&
                   *(p + 4) == '"') {
                    p += 5;

                    /* Extract text into a stack buffer — ONE verse at a time */
                    char text_buf[512];
                    size_t text_len = 0;
                    bool escaped = false;

                    while(*p != '\0' && text_len < sizeof(text_buf) - 1) {
                        if(escaped) {
                            if(*p == 'n') {
                                text_buf[text_len++] = '\n';
                            } else if(*p == 't') {
                                text_buf[text_len++] = '\t';
                            } else if(*p == 'r') {
                                text_buf[text_len++] = '\r';
                            } else {
                                text_buf[text_len++] = *p;
                            }
                            escaped = false;
                        } else if(*p == '\\') {
                            escaped = true;
                        } else if(*p == '"') {
                            break;
                        } else {
                            text_buf[text_len++] = *p;
                        }
                        p++;
                    }
                    text_buf[text_len] = '\0';

                    /* Apply verse range filter */
                    if(start_verse == 0 ||
                       (verse_num >= start_verse && verse_num <= end_verse)) {
                        bible_sanitize_text(text_buf, 511);
                        count++;
                        if(!callback(verse_num, text_buf, ctx)) {
                            return true; /* caller requested early stop */
                        }
                    }
                    break;
                }
                p++;
            }
        } else {
            p++;
        }
    }

    return count > 0;
}

/* ============================================================================
 * Context structure for bible_load_chapter callback
 * ============================================================================ */

typedef struct {
    BibleAppState* state;
    uint16_t lines_before; /* snapshot of line_count before loading */
} WrapContext;

static bool bible_wrap_callback(uint16_t verse_num, const char* text, void* ctx) {
    WrapContext* wctx = (WrapContext*)ctx;
    BibleAppState* state = wctx->state;

    /* Ensure lines array has enough capacity */
    if(state->line_count >= state->lines_capacity) {
        if(!bible_lines_ensure(state, state->line_count + 15)) {
            return false; /* OOM — stop scanning */
        }
    }

    /* Wrap this verse into lines, writing directly into state->lines */
    bible_word_wrap(
        text,
        verse_num,
        BIBLE_MAX_CHARS_PER_LINE,
        state->lines,
        &state->line_count,
        state->lines_capacity);

    return true;
}

/* ============================================================================
 * bible_load_chapter — single pass, no verse array in RAM
 * ============================================================================ */

bool bible_load_chapter(
    uint8_t book_index,
    uint16_t chapter,
    uint16_t start_verse,
    uint16_t end_verse,
    BibleAppState* state) {
    furi_check(state);

    char path[128];
    if(!bible_build_path(book_index, chapter, path, sizeof(path))) {
        return false;
    }

    /* Read JSON file into a temporary buffer */
    uint8_t* buf = NULL;
    size_t total = 0;
    if(!bible_read_chapter_file(path, &buf, &total)) {
        return false;
    }

    /* Clear previous lines and passage */
    state->line_count = 0;
    memset(&state->passage, 0, sizeof(BiblePassage));

    WrapContext ctx = {.state = state, .lines_before = 0};

    /* Scan verses and wrap each one into lines immediately */
    bool ok = bible_scan_verses_from_json(
        (const char*)buf, total, start_verse, end_verse, bible_wrap_callback, &ctx);

    free(buf);

    if(!ok || state->line_count == 0) {
        state->line_count = 0;
        return false;
    }

    /* Populate passage metadata */
    state->passage.book_index = book_index;
    state->passage.chapter = chapter;
    state->passage.start_verse = start_verse;
    state->passage.end_verse = end_verse;

    /* Derive verse_count from the highest verse_number seen in lines */
    uint16_t max_verse = 0;
    for(uint16_t i = 0; i < state->line_count; i++) {
        if(state->lines[i].verse_number > max_verse) {
            max_verse = state->lines[i].verse_number;
        }
    }
    state->passage.verse_count = max_verse;

    return true;
}

/* ============================================================================
 * bible_load_chapter_verse_scan — stream verses via callback (no RAM storage)
 * ============================================================================ */

bool bible_load_chapter_verse_scan(
    uint8_t book_index,
    uint16_t chapter,
    uint16_t start_verse,
    uint16_t end_verse,
    BibleVerseCallback callback,
    void* ctx) {
    char path[128];
    if(!bible_build_path(book_index, chapter, path, sizeof(path))) {
        return false;
    }

    uint8_t* buf = NULL;
    size_t total = 0;
    if(!bible_read_chapter_file(path, &buf, &total)) {
        return false;
    }

    bool ok = bible_scan_verses_from_json(
        (const char*)buf, total, start_verse, end_verse, callback, ctx);

    free(buf);
    return ok;
}
