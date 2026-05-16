#include "bible_app.h"
#include "bible_books.h"
#include "bible_renderer.h"

#include <string.h>

/* ============================================================================
 * BookList layout constants — match Rust src/views/book_list.rs exactly
 * ============================================================================ */
#define BOOK_LIST_LINE_HEIGHT   10
#define BOOK_LIST_HEADER_HEIGHT 12

/* ============================================================================
 * BookList view — draw callback
 * ============================================================================ */
void bible_bsb_view_book_list_draw(Canvas* canvas, void* ctx) {
    BibleApp* app = ctx;
    BibleAppState* state = app->state;

    canvas_clear(canvas);
    canvas_set_font(canvas, FontPrimary);

    /* Header: active filter in < > brackets */
    char header[16];
    if(state->book_filter_idx == 0) {
        strlcpy(header, "< All >", sizeof(header));
    } else {
        snprintf(header, sizeof(header), "< %s >", BIBLE_FILTER_LABELS[state->book_filter_idx]);
    }
    canvas_draw_str(canvas, BIBLE_MARGIN_X, 10, header);

    /* Divider line */
    canvas_draw_line(
        canvas, 0, BOOK_LIST_HEADER_HEIGHT, BIBLE_SCREEN_WIDTH, BOOK_LIST_HEADER_HEIGHT);

    /* Build filtered list */
    uint8_t filtered[BIBLE_BOOK_COUNT];
    uint8_t filtered_count = get_filtered_books(state->book_filter_idx, filtered);
    if(filtered_count == 0) {
        return;
    }

    /* Visible range */
    uint8_t max_visible =
        (BIBLE_SCREEN_HEIGHT - BOOK_LIST_HEADER_HEIGHT - 2) / BOOK_LIST_LINE_HEIGHT;
    if(max_visible == 0) max_visible = 1;

    uint8_t start_idx = state->book_scroll;
    if(start_idx + max_visible > filtered_count) {
        start_idx = filtered_count > max_visible ? filtered_count - max_visible : 0;
    }

    /* Draw each visible book */
    for(uint8_t i = 0; i < max_visible; i++) {
        uint8_t list_idx = start_idx + i;
        if(list_idx >= filtered_count) break;

        uint8_t book_idx = filtered[list_idx];
        uint8_t y = BOOK_LIST_HEADER_HEIGHT + 2 + (i * BOOK_LIST_LINE_HEIGHT) + BIBLE_CHAR_HEIGHT;

        if(book_idx == state->selected_book) {
            bible_draw_inverted_highlight(
                canvas,
                0,
                y - 9,
                BIBLE_SCREEN_WIDTH,
                BOOK_LIST_LINE_HEIGHT,
                OSIS_BOOK_NAMES[book_idx],
                BIBLE_MARGIN_X + 4,
                y);
        } else {
            canvas_draw_str(canvas, BIBLE_MARGIN_X + 4, y, OSIS_BOOK_NAMES[book_idx]);
        }
    }

    /* Scroll indicator */
    bible_draw_scroll_indicator(
        canvas, state->book_scroll, filtered_count, max_visible, BOOK_LIST_HEADER_HEIGHT);
}

/* ============================================================================
 * BookList view — input callback
 * ============================================================================ */
bool bible_bsb_view_book_list_input(InputEvent* event, void* ctx) {
    BibleApp* app = ctx;
    BibleAppState* state = app->state;

    /* Only process Press, Repeat, Short, Long — ignore Release */
    if(event->type != InputTypePress && event->type != InputTypeRepeat &&
       event->type != InputTypeShort && event->type != InputTypeLong) {
        return false;
    }

    /* Build filtered list */
    uint8_t filtered[BIBLE_BOOK_COUNT];
    uint8_t filtered_count = get_filtered_books(state->book_filter_idx, filtered);
    if(filtered_count == 0) {
        return false;
    }

    /* Find current position within filtered list */
    uint8_t current_idx = 0;
    for(uint8_t i = 0; i < filtered_count; i++) {
        if(filtered[i] == state->selected_book) {
            current_idx = i;
            break;
        }
    }

    uint8_t max_visible =
        (BIBLE_SCREEN_HEIGHT - BOOK_LIST_HEADER_HEIGHT - 2) / BOOK_LIST_LINE_HEIGHT;
    if(max_visible == 0) max_visible = 1;

    bool consumed = false;

    if(event->key == InputKeyUp &&
       (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Move up, wrap to end */
        uint8_t next_idx = (current_idx > 0) ? current_idx - 1 : filtered_count - 1;
        state->selected_book = filtered[next_idx];

        /* Auto-scroll */
        if(next_idx < state->book_scroll) {
            state->book_scroll = next_idx;
        } else if(next_idx >= state->book_scroll + max_visible) {
            state->book_scroll = next_idx >= max_visible ? next_idx - (max_visible - 1) : 0;
        }
        consumed = true;

    } else if(
        event->key == InputKeyDown &&
        (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Move down, wrap to start */
        uint8_t next_idx = (current_idx + 1 < filtered_count) ? current_idx + 1 : 0;
        state->selected_book = filtered[next_idx];

        /* Auto-scroll */
        if(next_idx >= state->book_scroll + max_visible) {
            state->book_scroll = next_idx >= max_visible ? next_idx - (max_visible - 1) : 0;
        } else if(next_idx < state->book_scroll) {
            state->book_scroll = next_idx;
        }
        consumed = true;

    } else if(event->key == InputKeyLeft && event->type == InputTypeShort) {
        /* Navigate to Collection scene */
        scene_manager_next_scene(app->scene_manager, BibleSceneCollection);
        consumed = true;

    } else if(event->key == InputKeyRight && event->type == InputTypeShort) {
        /* Navigate to BookFilter scene */
        scene_manager_next_scene(app->scene_manager, BibleSceneBookFilter);
        consumed = true;

    } else if(event->key == InputKeyOk && event->type == InputTypeShort) {
        /* Navigate to ChapterList for selected book */
        state->selected_chapter = 1;
        scene_manager_next_scene(app->scene_manager, BibleSceneChapterList);
        consumed = true;

    } else if(event->key == InputKeyBack && event->type == InputTypeShort) {
        /* Let SceneManager handle Back: BookList scene on_event will reset
         * filter (if active) or stop the app (if already "All"). */
        consumed = false;
    }

    return consumed;
}
