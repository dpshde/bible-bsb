#include "bible_app.h"
#include "bible_books.h"
#include "bible_renderer.h"
#include "bible_loader.h"

#include <string.h>

/* ============================================================================
 * VerseSelect layout constants — match Rust src/views/verse_select.rs exactly
 * ============================================================================ */
#define VERSE_SELECT_HEADER_H 12
#define VERSE_SELECT_LINE_H   12
#define VERSE_SELECT_ROW_1_Y  (VERSE_SELECT_HEADER_H + 10) /* y = 22 */
#define VERSE_SELECT_ROW_2_Y  (VERSE_SELECT_ROW_1_Y + VERSE_SELECT_LINE_H) /* y = 34 */
#define VERSE_SELECT_ROW_3_Y  (VERSE_SELECT_ROW_2_Y + VERSE_SELECT_LINE_H) /* y = 46 */
#define VERSE_SELECT_HINT_Y   60

/* ============================================================================
 * VerseSelect view — draw callback
 * ============================================================================ */
void bible_bsb_view_verse_select_draw(Canvas* canvas, void* ctx) {
    BibleApp* app = ctx;
    BibleAppState* state = app->state;

    canvas_clear(canvas);
    canvas_set_font(canvas, FontPrimary);

    /* Header: "{Book} {Chapter}" */
    char header[48];
    snprintf(
        header,
        sizeof(header),
        "%s %u",
        OSIS_BOOK_NAMES[state->selected_book],
        (unsigned int)state->selected_chapter);
    canvas_draw_str(canvas, BIBLE_MARGIN_X, 10, header);
    canvas_draw_line(canvas, 0, VERSE_SELECT_HEADER_H, BIBLE_SCREEN_WIDTH, VERSE_SELECT_HEADER_H);

    uint16_t actual_max = max_verse_for_chapter(state->selected_book, state->selected_chapter);
    if(actual_max == 0) {
        actual_max = 40;
    }

    /* --- Row 1: "All verses" --- */
    bool all_selected = (state->verse_select_mode == 0);
    if(all_selected) {
        bible_draw_inverted_highlight(
            canvas,
            0,
            VERSE_SELECT_ROW_1_Y - 10,
            BIBLE_SCREEN_WIDTH,
            VERSE_SELECT_LINE_H,
            "All verses",
            4,
            VERSE_SELECT_ROW_1_Y);
    } else {
        canvas_draw_str(canvas, 4, VERSE_SELECT_ROW_1_Y, "All verses");
    }

    /* --- Row 2: "Start: {n}" --- */
    bool start_selected = (state->verse_select_mode == 1);
    char start_label[32];
    snprintf(
        start_label, sizeof(start_label), "Start: %u", (unsigned int)state->selected_start_verse);
    if(start_selected) {
        bible_draw_inverted_highlight(
            canvas,
            0,
            VERSE_SELECT_ROW_2_Y - 10,
            BIBLE_SCREEN_WIDTH,
            VERSE_SELECT_LINE_H,
            start_label,
            4,
            VERSE_SELECT_ROW_2_Y);
    } else {
        canvas_draw_str(canvas, 4, VERSE_SELECT_ROW_2_Y, start_label);
    }

    /* --- Row 3: "End: {n}" --- */
    bool end_selected = (state->verse_select_mode == 2);
    char end_label[32];
    snprintf(end_label, sizeof(end_label), "End: %u", (unsigned int)state->selected_end_verse);
    if(end_selected) {
        bible_draw_inverted_highlight(
            canvas,
            0,
            VERSE_SELECT_ROW_3_Y - 10,
            BIBLE_SCREEN_WIDTH,
            VERSE_SELECT_LINE_H,
            end_label,
            4,
            VERSE_SELECT_ROW_3_Y);
    } else {
        canvas_draw_str(canvas, 4, VERSE_SELECT_ROW_3_Y, end_label);
    }

    /* --- Bottom hint (context-sensitive) --- */
    canvas_set_font(canvas, FontSecondary);
    const char* hint;
    if(state->verse_select_mode == 0) {
        hint = "OK=read, Back=back";
    } else {
        hint = "U/D=nav L/R=vs OK=read";
    }
    canvas_draw_str(canvas, BIBLE_MARGIN_X, VERSE_SELECT_HINT_Y, hint);
}

/* ============================================================================
 * VerseSelect view — input callback
 * ============================================================================ */
bool bible_bsb_view_verse_select_input(InputEvent* event, void* ctx) {
    BibleApp* app = ctx;
    BibleAppState* state = app->state;

    /* Only process Press, Repeat, Short, Long — ignore Release */
    if(event->type != InputTypePress && event->type != InputTypeRepeat &&
       event->type != InputTypeShort && event->type != InputTypeLong) {
        return false;
    }

    uint16_t max_v = max_verse_for_chapter(state->selected_book, state->selected_chapter);
    uint16_t actual_max = (max_v > 0) ? max_v : 40;

    bool consumed = false;

    if(event->key == InputKeyUp &&
       (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Up: End -> Start -> All */
        if(state->verse_select_mode == 2) {
            state->verse_select_mode = 1; /* End -> Start */
        } else if(state->verse_select_mode == 1) {
            state->verse_select_mode = 0; /* Start -> All */
        }
        /* All stays All */
        consumed = true;

    } else if(
        event->key == InputKeyDown &&
        (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Down: All -> Start -> End */
        if(state->verse_select_mode == 0) {
            state->verse_select_mode = 1; /* All -> Start */
        } else if(state->verse_select_mode == 1) {
            state->verse_select_mode = 2; /* Start -> End */
        }
        /* End stays End */
        consumed = true;

    } else if(
        event->key == InputKeyLeft &&
        (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Left: decrement verse */
        if(state->verse_select_mode == 1) {
            /* Start mode: decrement start verse (min=1) */
            if(state->selected_start_verse > 1) {
                state->selected_start_verse -= 1;
            }
        } else if(state->verse_select_mode == 2) {
            /* End mode: decrement end verse (min=start_verse) */
            if(state->selected_end_verse > state->selected_start_verse) {
                state->selected_end_verse -= 1;
            }
        }
        consumed = true;

    } else if(
        event->key == InputKeyRight &&
        (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Right: increment verse */
        if(state->verse_select_mode == 1) {
            /* Start mode: increment start verse, auto-bump end if needed */
            if(state->selected_start_verse < actual_max) {
                state->selected_start_verse += 1;
                if(state->selected_end_verse < state->selected_start_verse) {
                    state->selected_end_verse = state->selected_start_verse;
                }
            }
        } else if(state->verse_select_mode == 2) {
            /* End mode: increment end verse (clamped to actual_max) */
            if(state->selected_end_verse < actual_max) {
                state->selected_end_verse += 1;
            }
        }
        consumed = true;

    } else if(event->key == InputKeyOk && event->type == InputTypeShort) {
        /* OK (Short): load chapter and go to Reader */
        uint16_t start_verse = (state->verse_select_mode == 0) ? 0 : state->selected_start_verse;
        uint16_t end_verse = (state->verse_select_mode == 0) ? 0 : state->selected_end_verse;

        bool loaded = bible_load_chapter(
            state->selected_book, state->selected_chapter, start_verse, end_verse, state);

        if(loaded && state->passage.verse_count > 0) {
            state->scroll_offset = 0;
            state->reader_came_from_collection = false;
            scene_manager_next_scene(app->scene_manager, BibleSceneReader);
        } else {
            bible_toast_set(&state->toast, "No BSB data");
        }
        consumed = true;

    } else if(event->key == InputKeyBack && event->type == InputTypeShort) {
        /* Back (Short): let SceneManager handle via VerseSelect scene on_event. */
        consumed = false;
    }

    return consumed;
}
