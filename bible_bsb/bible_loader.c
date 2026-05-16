#include "bible_loader.h"
#include "bible_books.h"

#include <furi.h>
#include <storage/storage.h>
#include <string.h>

/* ============================================================================
 * Chapter loader — read JSON from SD in 1KB chunks, extract verses
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

/* Minimal JSON parser: scan for "n": and "t":" pairs.
 * json_len is the byte length of the JSON buffer (not counting null terminator).
 */
static uint16_t bible_parse_verses(
    const char* json,
    size_t json_len,
    uint16_t start_verse,
    uint16_t end_verse,
    BibleVerse* out_verses,
    uint16_t max_verses) {
    const char* p = json;
    uint16_t count = 0;

    while(*p != '\0' && count < max_verses) {
        /* Bounds-check before looking for "n": (need 4 bytes ahead) */
        size_t offset = (size_t)(p - json);
        if(offset + 4 > json_len) break;

        /* Look for "n": */
        if(*p == '"' && *(p + 1) == 'n' && *(p + 2) == '"' && *(p + 3) == ':') {
            p += 4;
            /* Skip whitespace */
            while(*p == ' ' || *p == '\t') p++;

            /* Parse verse number */
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

                    /* Extract text until closing quote */
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

                    /* Apply filter and sanitization */
                    if(start_verse == 0 || (verse_num >= start_verse && verse_num <= end_verse)) {
                        out_verses[count].number = verse_num;
                        bible_sanitize_text(text_buf, 511);
                        strlcpy(out_verses[count].text, text_buf, sizeof(out_verses[count].text));
                        count++;
                    }
                    break;
                }
                p++;
            }
        } else {
            p++;
        }
    }

    return count;
}

bool bible_load_chapter(
    uint8_t book_index,
    uint16_t chapter,
    uint16_t start_verse,
    uint16_t end_verse,
    BiblePassage* out_passage) {
    furi_check(out_passage);

    const char* osis = OSIS_BOOK_CODES[book_index];
    if(osis == NULL || chapter == 0) {
        return false;
    }

    /* Build path: /ext/apps_data/kindled_spark/bsb/{osis_lower}/{chapter}.json */
    char path[128];
    snprintf(
        path,
        sizeof(path),
        BSB_PATH_PREFIX "%s/%u.json",
        osis,
        (unsigned int)chapter);

    /* Convert OSIS code to lowercase in-place */
    for(size_t i = strlen(BSB_PATH_PREFIX); path[i] != '/' && path[i] != '\0'; i++) {
        if(path[i] >= 'A' && path[i] <= 'Z') {
            path[i] = path[i] - 'A' + 'a';
        }
    }

    Storage* storage = furi_record_open(RECORD_STORAGE);
    File* file = storage_file_alloc(storage);
    bool ok = storage_file_open(file, path, FSAM_READ, FSOM_OPEN_EXISTING);

    if(!ok) {
        storage_file_close(file);
        storage_file_free(file);
        furi_record_close(RECORD_STORAGE);
        return false;
    }

    /* Read file in 1KB chunks into dynamically grown buffer (max 20KB) */
    uint8_t chunk[BIBLE_READ_CHUNK];
    uint8_t* buf = NULL;
    size_t total = 0;
    size_t capacity = 0;

    while(total < BIBLE_MAX_FILE_SIZE) {
        size_t n = storage_file_read(file, chunk, sizeof(chunk));
        if(n == 0) break;

        /* Clamp so total never exceeds max file size */
        if(total + n > BIBLE_MAX_FILE_SIZE) {
            n = BIBLE_MAX_FILE_SIZE - total;
        }

        if(total + n > capacity) {
            size_t new_cap = capacity + BIBLE_READ_CHUNK;
            if(new_cap > BIBLE_MAX_FILE_SIZE) {
                new_cap = BIBLE_MAX_FILE_SIZE;
            }
            /* +1 ensures room for null terminator without extra realloc */
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

    /* Null-terminate — capacity always has +1 headroom from realloc above */
    buf[total] = '\0';

    /* Parse verses */
    uint16_t verse_count = bible_parse_verses(
        (const char*)buf,
        total,
        start_verse,
        end_verse,
        out_passage->verses,
        BIBLE_MAX_VERSES);

    free(buf);

    if(verse_count > 0) {
        out_passage->book_index = book_index;
        out_passage->chapter = chapter;
        out_passage->start_verse = start_verse;
        out_passage->end_verse = end_verse;
        out_passage->verse_count = verse_count;
        return true;
    }

    return false;
}
