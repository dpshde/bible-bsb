#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#include <furi.h>

/* ============================================================================
 * Max values
 * ============================================================================ */
#define BIBLE_MAX_BOOKS           66
#define BIBLE_MAX_CHAPTERS        150
#define BIBLE_MAX_FILTER_OPTIONS  22
#define BIBLE_MAX_COLLECTION      100
#define BIBLE_MAX_VERSES          176 /* Psalms 119 = 176 verses */
#define BIBLE_MAX_LINES           512
#define BIBLE_MAX_FILE_SIZE       20000
#define BIBLE_MAX_COLLECTION_SIZE 2048
#define BIBLE_READ_CHUNK          1024

/* ============================================================================
 * Toast system
 * ============================================================================ */
#define BIBLE_TOAST_MAX_LEN 64
#define BIBLE_TOAST_FRAMES  60

typedef struct {
    char message[BIBLE_TOAST_MAX_LEN];
    uint8_t timer;
} BibleToast;

static inline void bible_toast_set(BibleToast* toast, const char* msg) {
    furi_check(toast);
    if(msg) {
        strlcpy(toast->message, msg, BIBLE_TOAST_MAX_LEN);
        toast->timer = BIBLE_TOAST_FRAMES;
    } else {
        toast->message[0] = '\0';
        toast->timer = 0;
    }
}

static inline void bible_toast_tick(BibleToast* toast) {
    if(toast->timer > 0) {
        toast->timer--;
        if(toast->timer == 0) {
            toast->message[0] = '\0';
        }
    }
}

static inline bool bible_toast_active(const BibleToast* toast) {
    return toast->timer > 0;
}

/* ============================================================================
 * Line (rendered wrapped line)
 * ============================================================================ */
typedef struct {
    char text[64]; /* max chars per line + verse prefix + safety */
    uint16_t verse_number; /* verse this line belongs to (0 = unassigned) */
    bool is_verse_number; /* true if first line of a verse (has number prefix) */
} BibleLine;

/* ============================================================================
 * Verse (loaded from JSON)
 * ============================================================================ */
typedef struct {
    uint16_t number;
    char text[512];
} BibleVerse;

/* ============================================================================
 * Passage (currently loaded chapter data)
 * ============================================================================ */
typedef struct {
    uint8_t book_index; /* 0-65 */
    uint16_t chapter; /* 1-150 */
    uint16_t start_verse;
    uint16_t end_verse;
    uint16_t verse_count;
    BibleVerse verses[BIBLE_MAX_VERSES];
} BiblePassage;

/* ============================================================================
 * Collection entry
 * ============================================================================ */
typedef struct {
    char scripture_ref[32];
    char scripture_display_ref[32];
    char scripture_translation[8];
    uint8_t book_index;
    uint16_t chapter;
    uint16_t start_verse;
    uint16_t end_verse;
    char captured_at[32];
    char note[64];
} BibleCollectionEntry;

/* ============================================================================
 * App state — central mutable state (mirrors Rust AppState)
 * ============================================================================ */
typedef struct BibleAppState {
    /* Navigation */
    uint8_t selected_book; /* 0-65 */
    uint16_t selected_chapter; /* 1-150 */
    uint16_t selected_start_verse;
    uint16_t selected_end_verse;
    uint8_t verse_select_mode; /* 0=All, 1=Start, 2=End */
    uint8_t book_filter_idx; /* 0-21 */
    uint16_t scroll_offset;
    uint16_t book_scroll;
    uint16_t collection_scroll;
    uint8_t action_menu_selection;

    /* Data */
    BiblePassage passage;
    BibleCollectionEntry collection[BIBLE_MAX_COLLECTION];
    uint8_t collection_count;
    bool collection_loaded;

    /* Rendering */
    BibleLine lines[BIBLE_MAX_LINES];
    uint16_t line_count;
    uint16_t current_page;

    /* Feedback */
    BibleToast toast;

    /* NFC / sharing */
    bool reader_came_from_collection;
    char nfc_url[128];
    bool nfc_emitting;
    bool nfc_is_export;
} BibleAppState;

/* ============================================================================
 * Helpers
 * ============================================================================ */
static inline void bible_app_state_init(BibleAppState* state) {
    furi_check(state);
    memset(state, 0, sizeof(BibleAppState));
    state->selected_book = 0;
    state->selected_chapter = 1;
    state->selected_start_verse = 1;
    state->selected_end_verse = 1;
    state->verse_select_mode = 0;
    state->book_filter_idx = 0;
    state->action_menu_selection = 0;
    state->collection_count = 0;
    state->collection_loaded = false;
    state->line_count = 0;
    state->current_page = 0;
    state->reader_came_from_collection = false;
    state->nfc_emitting = false;
    state->nfc_is_export = false;
}
