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
 * Passage (currently loaded chapter metadata — verses live on SD, not RAM)
 * ============================================================================ */
typedef struct {
    uint8_t book_index; /* 0-65 */
    uint16_t chapter; /* 1-150 */
    uint16_t start_verse;
    uint16_t end_verse;
    uint16_t verse_count;
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
    uint8_t current_scene; /* matches BibleScene enum */
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
    BibleCollectionEntry* collection; /* dynamically allocated, NULL if empty */
    uint8_t collection_count;
    uint8_t collection_capacity;
    bool collection_loaded;

    /* Rendering */
    BibleLine* lines; /* dynamically allocated, NULL if no lines */
    uint16_t line_count;
    uint16_t lines_capacity;
    uint16_t current_page;

    /* Feedback */
    BibleToast toast;

    /* NFC / sharing */
    bool reader_came_from_collection;
    char nfc_url[128];
    bool nfc_emitting;
    bool nfc_is_export;
    uint8_t nfc_pulse_counter;
} BibleAppState;

/* ============================================================================
 * Dynamic memory helpers
 * ============================================================================ */

/** Ensure lines array has at least `capacity` slots. Grows incrementally (max ~1KB per realloc). */
static inline bool bible_lines_ensure(BibleAppState* state, uint16_t capacity) {
    furi_check(state);
    if(capacity == 0) return true;
    if(state->lines && state->lines_capacity >= capacity) return true;

    /* Max 15 lines per realloc: 15 * sizeof(BibleLine) <= 1020 bytes */
    const uint16_t LINES_PER_GROW = 15;

    uint16_t new_cap = state->lines_capacity;
    while(new_cap < capacity) {
        new_cap += LINES_PER_GROW;
    }
    if(new_cap > BIBLE_MAX_LINES) new_cap = BIBLE_MAX_LINES;

    BibleLine* new_lines = realloc(state->lines, new_cap * sizeof(BibleLine));
    if(!new_lines) return false;
    /* Zero-initialize newly allocated slots */
    if(new_cap > state->lines_capacity) {
        memset(
            new_lines + state->lines_capacity,
            0,
            (new_cap - state->lines_capacity) * sizeof(BibleLine));
    }
    state->lines = new_lines;
    state->lines_capacity = new_cap;
    return true;
}

/** Free the lines array. */
static inline void bible_lines_free(BibleAppState* state) {
    furi_check(state);
    if(state->lines) {
        free(state->lines);
        state->lines = NULL;
    }
    state->line_count = 0;
    state->lines_capacity = 0;
}

/** Ensure collection array has at least `capacity` slots. */
static inline bool bible_collection_ensure(BibleAppState* state, uint16_t capacity) {
    furi_check(state);
    if(capacity == 0) return true;
    if(state->collection && state->collection_capacity >= capacity) return true;

    uint16_t new_cap = state->collection_capacity > 0 ? state->collection_capacity * 2 : 8;
    while(new_cap < capacity)
        new_cap *= 2;
    if(new_cap > BIBLE_MAX_COLLECTION) new_cap = BIBLE_MAX_COLLECTION;

    BibleCollectionEntry* new_col =
        realloc(state->collection, new_cap * sizeof(BibleCollectionEntry));
    if(!new_col) return false;
    state->collection = new_col;
    state->collection_capacity = new_cap;
    return true;
}

/** Free the collection array. */
static inline void bible_collection_free(BibleAppState* state) {
    furi_check(state);
    if(state->collection) {
        free(state->collection);
        state->collection = NULL;
    }
    state->collection_count = 0;
    state->collection_capacity = 0;
}

/* ============================================================================
 * Helpers
 * ============================================================================ */
static inline void bible_app_state_init(BibleAppState* state) {
    furi_check(state);
    memset(state, 0, sizeof(BibleAppState));
    state->current_scene = 0; /* BibleSceneBookList */
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
    state->lines_capacity = 0;
    state->current_page = 0;
    state->reader_came_from_collection = false;
    state->nfc_emitting = false;
    state->nfc_is_export = false;
}

/** Free all dynamically allocated memory in the state. Call before free(state). */
static inline void bible_app_state_deinit(BibleAppState* state) {
    furi_check(state);
    bible_lines_free(state);
    bible_collection_free(state);
}
