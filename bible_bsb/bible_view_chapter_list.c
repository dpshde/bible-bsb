#include "bible_app.h"
#include "bible_books.h"
#include "bible_renderer.h"

#include <string.h>

/* ============================================================================
 * ChapterList layout constants — match Rust src/views/chapter_list.rs exactly
 * ============================================================================ */
#define CHAPTER_LIST_COLS     5
#define CHAPTER_LIST_CELL_W   24
#define CHAPTER_LIST_CELL_H   14
#define CHAPTER_LIST_HEADER_H 12
#define CHAPTER_LIST_MAX_ROWS 3

/* ============================================================================
 * Static string lookup for chapter numbers 1–150
 * ============================================================================ */
static const char* CHAPTER_NUMS[151] = {
    "0",   "1",   "2",   "3",   "4",   "5",   "6",   "7",   "8",   "9",   "10",  "11",  "12",
    "13",  "14",  "15",  "16",  "17",  "18",  "19",  "20",  "21",  "22",  "23",  "24",  "25",
    "26",  "27",  "28",  "29",  "30",  "31",  "32",  "33",  "34",  "35",  "36",  "37",  "38",
    "39",  "40",  "41",  "42",  "43",  "44",  "45",  "46",  "47",  "48",  "49",  "50",  "51",
    "52",  "53",  "54",  "55",  "56",  "57",  "58",  "59",  "60",  "61",  "62",  "63",  "64",
    "65",  "66",  "67",  "68",  "69",  "70",  "71",  "72",  "73",  "74",  "75",  "76",  "77",
    "78",  "79",  "80",  "81",  "82",  "83",  "84",  "85",  "86",  "87",  "88",  "89",  "90",
    "91",  "92",  "93",  "94",  "95",  "96",  "97",  "98",  "99",  "100", "101", "102", "103",
    "104", "105", "106", "107", "108", "109", "110", "111", "112", "113", "114", "115", "116",
    "117", "118", "119", "120", "121", "122", "123", "124", "125", "126", "127", "128", "129",
    "130", "131", "132", "133", "134", "135", "136", "137", "138", "139", "140", "141", "142",
    "143", "144", "145", "146", "147", "148", "149", "150",
};

/* ============================================================================
 * ChapterList view — draw callback
 * ============================================================================ */
void bible_bsb_view_chapter_list_draw(Canvas* canvas, void* ctx) {
    BibleApp* app = ctx;
    BibleAppState* state = app->state;

    canvas_clear(canvas);
    canvas_set_font(canvas, FontPrimary);

    /* Header: book name */
    canvas_draw_str(canvas, BIBLE_MARGIN_X, 10, OSIS_BOOK_NAMES[state->selected_book]);
    canvas_draw_line(canvas, 0, CHAPTER_LIST_HEADER_H, BIBLE_SCREEN_WIDTH, CHAPTER_LIST_HEADER_H);

    uint8_t max_chapter = BOOK_CHAPTER_COUNTS[state->selected_book];
    uint8_t total_rows = (max_chapter + CHAPTER_LIST_COLS - 1) / CHAPTER_LIST_COLS;
    if(total_rows < 1) total_rows = 1;

    uint8_t selected_row = (state->selected_chapter - 1) / CHAPTER_LIST_COLS;

    uint8_t start_row =
        (selected_row >= CHAPTER_LIST_MAX_ROWS) ? (selected_row - CHAPTER_LIST_MAX_ROWS + 1) : 0;

    for(uint8_t row = start_row; row < start_row + CHAPTER_LIST_MAX_ROWS && row < total_rows;
        row++) {
        for(uint8_t col = 0; col < CHAPTER_LIST_COLS; col++) {
            uint8_t chapter_num = row * CHAPTER_LIST_COLS + col + 1;
            if(chapter_num > max_chapter) {
                break;
            }

            uint8_t display_row = row - start_row;
            uint8_t x = 4 + (col * CHAPTER_LIST_CELL_W);
            uint8_t y = CHAPTER_LIST_HEADER_H + 4 + (display_row * CHAPTER_LIST_CELL_H);
            bool is_selected = (chapter_num == state->selected_chapter);

            if(is_selected) {
                canvas_draw_box(canvas, x, y, CHAPTER_LIST_CELL_W - 2, CHAPTER_LIST_CELL_H - 2);
                canvas_set_color(canvas, ColorWhite);
            }

            canvas_draw_str(canvas, x + 4, y + 10, CHAPTER_NUMS[chapter_num]);

            if(is_selected) {
                canvas_set_color(canvas, ColorBlack);
            }
        }
    }

    /* Scroll indicator */
    if(total_rows > CHAPTER_LIST_MAX_ROWS) {
        int32_t thumb_height = ((CHAPTER_LIST_MAX_ROWS * 50) / total_rows);
        if(thumb_height < 4) {
            thumb_height = 4;
        }
        int32_t thumb_y = 14;
        if(total_rows > CHAPTER_LIST_MAX_ROWS) {
            thumb_y += (int32_t)start_row * (50 - thumb_height) /
                       (int32_t)(total_rows - CHAPTER_LIST_MAX_ROWS);
        }
        canvas_draw_box(canvas, 126, thumb_y, 2, thumb_height);
    }
}

/* ============================================================================
 * ChapterList view — input callback
 * ============================================================================ */
bool bible_bsb_view_chapter_list_input(InputEvent* event, void* ctx) {
    BibleApp* app = ctx;
    BibleAppState* state = app->state;

    /* Only process Press, Repeat, Short, Long — ignore Release */
    if(event->type != InputTypePress && event->type != InputTypeRepeat &&
       event->type != InputTypeShort && event->type != InputTypeLong) {
        return false;
    }

    uint8_t max_chapter = BOOK_CHAPTER_COUNTS[state->selected_book];
    uint8_t cols = CHAPTER_LIST_COLS;
    bool consumed = false;

    if(event->key == InputKeyUp &&
       (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Move up by 5 chapters */
        if(state->selected_chapter > cols) {
            state->selected_chapter -= cols;
        }
        consumed = true;

    } else if(
        event->key == InputKeyDown &&
        (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Move down by 5 chapters, clamped to max */
        if(state->selected_chapter + cols <= max_chapter) {
            state->selected_chapter += cols;
        } else if(state->selected_chapter < max_chapter) {
            state->selected_chapter = max_chapter;
        }
        consumed = true;

    } else if(
        event->key == InputKeyLeft &&
        (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Decrement chapter by 1 */
        if(state->selected_chapter > 1) {
            state->selected_chapter -= 1;
        }
        consumed = true;

    } else if(
        event->key == InputKeyRight &&
        (event->type == InputTypePress || event->type == InputTypeRepeat)) {
        /* Increment chapter by 1 */
        if(state->selected_chapter < max_chapter) {
            state->selected_chapter += 1;
        }
        consumed = true;

    } else if(event->key == InputKeyOk && event->type == InputTypeShort) {
        /* Navigate to VerseSelect, reset verse mode to All */
        state->verse_select_mode = 0; /* All */
        state->selected_start_verse = 1;
        state->selected_end_verse = 1;
        scene_manager_next_scene(app->scene_manager, BibleSceneVerseSelect);
        consumed = true;

    } else if(event->key == InputKeyBack && event->type == InputTypeShort) {
        /* Return to BookList — let SceneManager handle it via on_event. */
        consumed = false;
    }

    return consumed;
}
