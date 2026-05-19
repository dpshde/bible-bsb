#include "bible_renderer.h"

#include <string.h>

/* ============================================================================
 * Word wrapping — split text on whitespace into lines fitting max_chars.
 * ============================================================================ */

void bible_word_wrap(
    const char* text,
    uint16_t verse_number,
    uint8_t max_chars,
    BibleLine* out_lines,
    uint16_t* out_count,
    uint16_t max_lines) {
    furi_check(text);
    furi_check(out_lines);
    furi_check(out_count);

    /* Prefix for the first line: "{n} " */
    char prefix[8];
    snprintf(prefix, sizeof(prefix), "%u ", (unsigned int)verse_number);
    uint8_t prefix_len = (uint8_t)strlen(prefix);

    /* Effective char budget for the first line (with prefix) and rest */
    uint8_t first_max = (max_chars > prefix_len) ? (max_chars - prefix_len) : 0;
    uint8_t rest_max = max_chars;

    bool first_line = true;
    char current[64];
    uint8_t current_len = 0;
    uint8_t budget = first_max;

    const char* p = text;
    char word[64];
    uint8_t word_len = 0;

    while(true) {
        char c = *p;
        bool is_whitespace = (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\0');

        if(!is_whitespace) {
            /* Accumulate word characters */
            if(word_len < sizeof(word) - 1) {
                word[word_len++] = c;
            }
        }

        if(is_whitespace && word_len > 0) {
            /* Word complete — decide whether it fits */
            uint8_t needed = word_len;
            if(current_len > 0) {
                needed += 1; /* space separator */
            }

            if(needed > budget && current_len > 0) {
                /* Flush current line */
                if(*out_count < max_lines) {
                    BibleLine* line = &out_lines[*out_count];
                    line->text[current_len] = '\0';
                    line->verse_number = verse_number;
                    line->is_verse_number = first_line;
                    if(first_line) {
                        /* Prepend verse number prefix in-place */
                        size_t text_len = strlen(line->text);
                        size_t pfx_len = prefix_len;
                        /* Shift existing text right, insert prefix */
                        if(pfx_len + text_len < sizeof(line->text)) {
                            memmove(line->text + pfx_len, line->text, text_len + 1);
                            memcpy(line->text, prefix, pfx_len);
                        }
                        first_line = false;
                    }
                    (*out_count)++;
                }
                /* Start fresh line with this word */
                memcpy(current, word, word_len);
                current_len = word_len;
                budget = rest_max;
            } else {
                /* Append to current line */
                if(current_len > 0) {
                    current[current_len++] = ' ';
                }
                memcpy(current + current_len, word, word_len);
                current_len += word_len;
            }
            word_len = 0;
        }

        if(c == '\0') {
            break;
        }
        p++;
    }

    /* Flush any remaining word that wasn't followed by whitespace */
    if(word_len > 0) {
        uint8_t needed = word_len;
        if(current_len > 0) {
            needed += 1;
        }
        if(needed > budget && current_len > 0) {
            if(*out_count < max_lines) {
                BibleLine* line = &out_lines[*out_count];
                line->text[current_len] = '\0';
                line->verse_number = verse_number;
                line->is_verse_number = first_line;
                if(first_line) {
                    /* Prepend verse number prefix in-place */
                    size_t text_len = strlen(line->text);
                    size_t pfx_len = prefix_len;
                    if(pfx_len + text_len < sizeof(line->text)) {
                        memmove(line->text + pfx_len, line->text, text_len + 1);
                        memcpy(line->text, prefix, pfx_len);
                    }
                    first_line = false;
                }
                (*out_count)++;
            }
            memcpy(current, word, word_len);
            current_len = word_len;
            budget = rest_max;
        } else {
            if(current_len > 0) {
                current[current_len++] = ' ';
            }
            memcpy(current + current_len, word, word_len);
            current_len += word_len;
        }
    }

    /* Flush the final line */
    if(current_len > 0 && *out_count < max_lines) {
        BibleLine* line = &out_lines[*out_count];
        memcpy(line->text, current, current_len);
        line->text[current_len] = '\0';
        line->verse_number = verse_number;
        line->is_verse_number = first_line;
        if(first_line) {
            /* Prepend verse number prefix in-place */
            size_t text_len = strlen(line->text);
            size_t pfx_len = prefix_len;
            if(pfx_len + text_len < sizeof(line->text)) {
                memmove(line->text + pfx_len, line->text, text_len + 1);
                memcpy(line->text, prefix, pfx_len);
            }
        }
        (*out_count)++;
    }
}

/* ============================================================================
 * Scroll indicator — 2px-wide thumb at x=126
 * ============================================================================ */

void bible_draw_scroll_indicator(
    Canvas* canvas,
    uint16_t scroll,
    uint16_t total,
    uint16_t visible,
    uint8_t header_height) {
    if(total <= visible) {
        return;
    }

    /* Match Rust calculation: thumb proportional to visible/total */
    int32_t avail = BIBLE_SCREEN_HEIGHT - header_height;
    int32_t thumb_height = (visible * BIBLE_SCREEN_HEIGHT / total);
    if(thumb_height < 4) {
        thumb_height = 4;
    }

    /* Position proportional to scroll offset */
    int32_t thumb_y = header_height;
    if(total > visible) {
        thumb_y += (int32_t)scroll * (avail - thumb_height) / (int32_t)(total - visible);
    }

    canvas_draw_box(canvas, 126, thumb_y, 2, thumb_height);
}

/* ============================================================================
 * Toast — centered black box with white text
 * ============================================================================ */

void bible_draw_toast(Canvas* canvas, const BibleToast* toast) {
    if(!toast || toast->timer == 0 || toast->message[0] == '\0') {
        return;
    }

    canvas_set_font(canvas, FontSecondary);

    /* Width based on message length (same formula as Rust: len*5 + 4) */
    size_t msg_len = strlen(toast->message);
    if(msg_len > 20) {
        msg_len = 20; /* Rust caps at 20 for width calc */
    }
    uint8_t toast_w = (uint8_t)(msg_len * 5) + 4;
    uint8_t toast_x = (BIBLE_SCREEN_WIDTH - toast_w) / 2;

    /* Black background box */
    canvas_draw_box(canvas, toast_x, 24, toast_w, 14);

    /* White text */
    canvas_set_color(canvas, ColorWhite);
    canvas_draw_str(canvas, toast_x + 2, 34, toast->message);

    /* Restore black drawing color */
    canvas_set_color(canvas, ColorBlack);
}

/* ============================================================================
 * Page rendering and pagination
 * ============================================================================ */

uint16_t bible_max_visible_lines(int16_t y_offset) {
    int16_t max_v = (BIBLE_SCREEN_HEIGHT - y_offset - BIBLE_MARGIN_Y) / BIBLE_LINE_HEIGHT;
    if(max_v < 1) max_v = 1;
    return (uint16_t)max_v;
}

void bible_render_page(
    Canvas* canvas,
    const BibleLine* lines,
    uint16_t line_count,
    uint16_t scroll_offset,
    int16_t y_offset) {
    if(!lines || line_count == 0) return;

    uint16_t max_visible = bible_max_visible_lines(y_offset);
    canvas_set_font(canvas, FontPrimary);

    for(uint16_t i = 0; i < max_visible; i++) {
        uint16_t idx = scroll_offset + i;
        if(idx >= line_count) break;

        int16_t y = y_offset + ((int16_t)i * BIBLE_LINE_HEIGHT);
        if(y + BIBLE_LINE_HEIGHT > BIBLE_SCREEN_HEIGHT - BIBLE_MARGIN_Y) break;

        canvas_draw_str(canvas, BIBLE_MARGIN_X, y + BIBLE_CHAR_HEIGHT - 1, lines[idx].text);
    }
}

uint16_t bible_total_pages(const BibleLine* lines, uint16_t line_count, int16_t y_offset) {
    UNUSED(lines);
    uint16_t max_visible = bible_max_visible_lines(y_offset);
    if(line_count == 0 || max_visible == 0) return 1;
    return (line_count + max_visible - 1) / max_visible;
}

/* ============================================================================
 * Inverted highlight — black box + white text
 * ============================================================================ */

void bible_draw_inverted_highlight(
    Canvas* canvas,
    uint8_t x,
    uint8_t y,
    uint8_t w,
    uint8_t h,
    const char* text,
    uint8_t text_x,
    uint8_t text_y) {
    /* Black filled box */
    canvas_draw_box(canvas, x, y, w, h);

    /* White text */
    canvas_set_color(canvas, ColorWhite);
    canvas_draw_str(canvas, text_x, text_y, text);

    /* Restore black drawing color */
    canvas_set_color(canvas, ColorBlack);
}
