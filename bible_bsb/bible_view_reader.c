#include "bible_view_reader.h"
#include "bible_renderer.h"
#include "bible_books.h"
#include "bible_loader.h"

#include <string.h>

/* ============================================================================
 * Reader layout constants — match Rust src/views/reader.rs exactly
 * ============================================================================ */
#define READER_HEADER_Y      8
#define READER_DIVIDER_Y     10
#define READER_CONTENT_Y     16

/* ============================================================================
 * Display ref builder — mirrors Rust Passage::display_ref()
 * ============================================================================ */
static void bible_passage_display_ref(const BiblePassage* passage, char* out, size_t out_len) {
    if(!passage || passage->verse_count == 0) {
        strlcpy(out, "No passage", out_len);
        return;
    }

    const char* book_name = OSIS_BOOK_NAMES[passage->book_index];
    if(passage->start_verse > 0) {
        if(passage->end_verse > passage->start_verse) {
            snprintf(
                out,
                out_len,
                "%s %u:%u-%u",
                book_name,
                (unsigned int)passage->chapter,
                (unsigned int)passage->start_verse,
                (unsigned int)passage->end_verse);
        } else {
            snprintf(
                out,
                out_len,
                "%s %u:%u",
                book_name,
                (unsigned int)passage->chapter,
                (unsigned int)passage->start_verse);
        }
    } else {
        snprintf(
            out, out_len, "%s %u", book_name, (unsigned int)passage->chapter);
    }
}

/* ============================================================================
 * Verse-first-line navigation helpers — match Rust next_verse_offset / prev_verse_offset
 * ============================================================================ */

static uint16_t reader_next_verse_offset(
    const BibleLine* lines,
    uint16_t line_count,
    uint16_t current) {
    if(current >= line_count) return current;

    uint16_t current_verse = lines[current].verse_number;
    for(uint16_t i = current + 1; i < line_count; i++) {
        if(lines[i].verse_number > current_verse) {
            return i;
        }
    }
    return current; /* no next verse */
}

static uint16_t reader_prev_verse_offset(
    const BibleLine* lines,
    uint16_t line_count,
    uint16_t current) {
    if(current >= line_count || line_count == 0) return 0;

    uint16_t current_verse = lines[current].verse_number;
    bool is_first = lines[current].is_verse_number;

    if(!is_first) {
        /* Jump to first line of current verse */
        for(uint16_t i = 0; i <= current && i < line_count; i++) {
            if(lines[i].verse_number == current_verse && lines[i].is_verse_number) {
                return i;
            }
        }
    }

    /* Find previous verse number */
    uint16_t prev_verse = 0;
    for(uint16_t i = 0; i < current && i < line_count; i++) {
        if(lines[i].verse_number < current_verse && lines[i].is_verse_number) {
            prev_verse = lines[i].verse_number;
        }
    }

    if(prev_verse == 0) {
        return 0; /* already at first verse */
    }

    for(uint16_t i = 0; i < current && i < line_count; i++) {
        if(lines[i].verse_number == prev_verse && lines[i].is_verse_number) {
            return i;
        }
    }
    return 0;
}

/* ============================================================================
 * Reader view — draw callback
 * ============================================================================ */
void bible_bsb_view_reader_draw(Canvas* canvas, void* ctx) {
    BibleApp* app = ctx;
    BibleAppState* state = app->state;

    canvas_clear(canvas);

    /* Header with passage reference */
    if(state->passage.verse_count > 0) {
        char ref_buf[48];
        bible_passage_display_ref(&state->passage, ref_buf, sizeof(ref_buf));
        canvas_set_font(canvas, FontSecondary);
        canvas_draw_str(canvas, BIBLE_MARGIN_X, READER_HEADER_Y, ref_buf);
        canvas_draw_line(canvas, 0, READER_DIVIDER_Y, BIBLE_SCREEN_WIDTH, READER_DIVIDER_Y);
    }

    /* Render paginated text */
    bible_render_page(
        canvas,
        state->lines,
        state->line_count,
        state->scroll_offset,
        READER_CONTENT_Y);

    /* Page indicator */
    uint16_t max_visible = bible_max_visible_lines(READER_CONTENT_Y);
    uint16_t total_pages = bible_total_pages(state->lines, state->line_count, READER_CONTENT_Y);
    uint16_t current_page;
    if(state->scroll_offset + max_visible >= state->line_count) {
        current_page = total_pages;
    } else {
        current_page = (state->scroll_offset / max_visible) + 1;
    }

    if(total_pages > 1) {
        canvas_set_font(canvas, FontSecondary);
        char page_str[16];
        snprintf(
            page_str, sizeof(page_str), "%u/%u", (unsigned int)current_page, (unsigned int)total_pages);
        uint8_t width = canvas_string_width(canvas, page_str);
        int16_t x = BIBLE_SCREEN_WIDTH - (int16_t)width - BIBLE_MARGIN_X;
        canvas_draw_str(canvas, x, BIBLE_SCREEN_HEIGHT - 1, page_str);
    }

    /* Toast */
    bible_draw_toast(canvas, &state->toast);
}

/* ============================================================================
 * Reader view — input callback
 * ============================================================================ */
bool bible_bsb_view_reader_input(InputEvent* event, void* ctx) {
    BibleApp* app = ctx;
    BibleAppState* state = app->state;

    /* Only process Press, Repeat, Short, Long — ignore Release */
    if(event->type != InputTypePress && event->type != InputTypeRepeat &&
       event->type != InputTypeShort && event->type != InputTypeLong) {
        return false;
    }

    uint16_t total_lines = state->line_count;
    uint16_t max_visible = bible_max_visible_lines(READER_CONTENT_Y);
    uint16_t max_scroll = (total_lines > max_visible) ? (total_lines - max_visible) : 0;

    bool consumed = false;

    if(event->key == InputKeyUp &&
       (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Up: jump to previous verse's first line */
        uint16_t new_offset = reader_prev_verse_offset(
            state->lines, state->line_count, state->scroll_offset);
        state->scroll_offset = new_offset;
        consumed = true;

    } else if(event->key == InputKeyDown &&
              (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Down: jump to next verse's first line */
        uint16_t new_offset = reader_next_verse_offset(
            state->lines, state->line_count, state->scroll_offset);
        if(new_offset <= max_scroll) {
            state->scroll_offset = new_offset;
        } else {
            state->scroll_offset = max_scroll;
        }
        consumed = true;

    } else if(event->key == InputKeyLeft &&
              (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Left: scroll up by 1 line */
        if(state->scroll_offset > 0) {
            state->scroll_offset -= 1;
        }
        consumed = true;

    } else if(event->key == InputKeyRight &&
              (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Right: scroll down by 1 line */
        if(state->scroll_offset < max_scroll) {
            state->scroll_offset += 1;
        }
        consumed = true;

    } else if(event->key == InputKeyOk && event->type == InputTypeLong) {
        /* OK Long: quick save — stub; storage-collection feature will wire this */
        bible_toast_set(&state->toast, "Saved!");
        consumed = true;

    } else if(event->key == InputKeyOk && event->type == InputTypeShort) {
        /* OK Short: open ActionMenu */
        state->action_menu_selection = 0;
        scene_manager_next_scene(app->scene_manager, BibleSceneActionMenu);
        consumed = true;

    } else if(event->key == InputKeyBack && event->type == InputTypeShort) {
        /* Back: return to VerseSelect or Collection */
        if(state->reader_came_from_collection) {
            scene_manager_next_scene(app->scene_manager, BibleSceneCollection);
        } else {
            scene_manager_previous_scene(app->scene_manager);
        }
        consumed = true;
    }

    return consumed;
}
