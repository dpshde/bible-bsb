/// Book list view — scrollable list of 66 books (OT/NT sections).

use flipperzero_sys as sys;
use crate::books;
use crate::views::{AppState, AppView, InputEvent};

const LINE_HEIGHT: i32 = 10;
const HEADER_HEIGHT: i32 = 12;
const MARGIN_X: i32 = 2;

pub fn draw(canvas: *mut sys::Canvas, state: &AppState) {
    unsafe {
        sys::canvas_set_font(canvas, sys::FontPrimary);

        // Header
        sys::canvas_draw_str(canvas, MARGIN_X, 10, c"Kindled Spark".as_ptr() as *const u8);
        sys::canvas_draw_line(canvas, 0, HEADER_HEIGHT, 128, HEADER_HEIGHT);

        let max_visible = ((64 - HEADER_HEIGHT - 2) / LINE_HEIGHT) as usize;
        let start_idx = state.book_scroll;

        for i in 0..max_visible {
            let idx = start_idx + i;
            if idx >= books::OSIS_BOOK_CODES.len() {
                break;
            }

            let y = HEADER_HEIGHT + 2 + (i as i32 * LINE_HEIGHT) + 8;
            let is_selected = idx == state.selected_book;

            if is_selected {
                sys::canvas_draw_box(canvas, 0, y - 8, 128, LINE_HEIGHT as usize);
                sys::canvas_set_color(canvas, sys::ColorWhite);
            }

            let name = books::OSIS_BOOK_NAMES[idx];
            let mut buf = [0u8; 32];
            let bytes = name.as_bytes();
            let len = bytes.len().min(buf.len() - 1);
            buf[..len].copy_from_slice(&bytes[..len]);
            buf[len] = 0;
            sys::canvas_draw_str(canvas, MARGIN_X + 4, y, buf.as_ptr() as *const u8);

            if is_selected {
                sys::canvas_set_color(canvas, sys::ColorBlack);
            }
        }

        // Scroll indicator
        let total = books::OSIS_BOOK_CODES.len();
        if total > max_visible {
            let thumb_height = ((max_visible * 64 / total).max(4)) as i32;
            let thumb_y = HEADER_HEIGHT + ((state.book_scroll as i32) * (64 - HEADER_HEIGHT - thumb_height) / ((total - max_visible) as i32));
            sys::canvas_draw_box(canvas, 126, thumb_y, 2, thumb_height as usize);
        }
    }
}

pub fn handle_input(event: &InputEvent, state: &mut AppState) -> bool {
    let max_visible = ((64 - HEADER_HEIGHT - 2) / LINE_HEIGHT) as usize;

    match event.key {
        sys::InputKeyUp => {
            if state.selected_book > 0 {
                state.selected_book -= 1;
                if state.selected_book < state.book_scroll {
                    state.book_scroll = state.selected_book;
                }
            }
        }
        sys::InputKeyDown => {
            if state.selected_book + 1 < books::OSIS_BOOK_CODES.len() {
                state.selected_book += 1;
                if state.selected_book >= state.book_scroll + max_visible {
                    state.book_scroll = state.selected_book.saturating_sub(max_visible - 1);
                }
            }
        }
        sys::InputKeyOk => {
            state.current_view = AppView::ChapterList;
            state.selected_chapter = 1;
        }
        sys::InputKeyBack => {
            return true; // Quit app
        }
        _ => {}
    }
    false
}
