use crate::books;
use crate::views::{AppState, AppView, InputEvent};
use alloc::vec::Vec;
use flipperzero_sys as sys;

const LINE_HEIGHT: i32 = 10;
const HEADER_HEIGHT: i32 = 12;
const MARGIN_X: i32 = 2;

const FILTER_CHARS: [char; 21] = [
    'A', 'C', 'D', 'E', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'R', 'S', 'T', 'Z', '1',
    '2', '3',
];

fn book_matches_filter(name: &str, filter: char) -> bool {
    let mut chars = name.chars();
    if let Some(c) = chars.next() {
        if c == filter {
            return true;
        }
    }
    if let Some(first_letter) = name.chars().find(|c| c.is_ascii_alphabetic()) {
        if first_letter == filter {
            return true;
        }
    }
    false
}

pub fn get_filtered_books(filter_idx: usize) -> Vec<usize> {
    let mut res = Vec::new();
    if filter_idx == 0 {
        for i in 0..66 {
            res.push(i);
        }
    } else {
        let filter = FILTER_CHARS[filter_idx - 1];
        for i in 0..66 {
            if book_matches_filter(crate::books::OSIS_BOOK_NAMES[i], filter) {
                res.push(i);
            }
        }
    }
    res
}

pub fn draw(canvas: *mut sys::Canvas, state: &AppState) {
    unsafe {
        sys::canvas_set_font(canvas, sys::FontPrimary);

        // Header
        let header_str = if state.book_filter_idx == 0 {
            alloc::format!("< All >")
        } else {
            alloc::format!("< {} >", FILTER_CHARS[state.book_filter_idx - 1])
        };
        let mut c_header = header_str.clone();
        c_header.push('\0');
        sys::canvas_draw_str(canvas, MARGIN_X, 10, c_header.as_ptr() as *const u8);
        sys::canvas_draw_line(canvas, 0, HEADER_HEIGHT, 128, HEADER_HEIGHT);

        let filtered_books = get_filtered_books(state.book_filter_idx);
        if filtered_books.is_empty() {
            return;
        }

        let max_visible = ((64 - HEADER_HEIGHT - 2) / LINE_HEIGHT) as usize;
        let start_idx = state.book_scroll;

        for i in 0..max_visible {
            if start_idx + i >= filtered_books.len() {
                break;
            }
            let book_idx = filtered_books[start_idx + i];

            let y = HEADER_HEIGHT + 2 + (i as i32 * LINE_HEIGHT) + 8;
            let is_selected = book_idx == state.selected_book;

            if is_selected {
                sys::canvas_draw_box(canvas, 0, y - 9, 128, LINE_HEIGHT as usize);
                sys::canvas_set_color(canvas, sys::ColorWhite);
            }

            let name = books::OSIS_BOOK_NAMES[book_idx];
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
        let total = filtered_books.len();
        if total > max_visible {
            let thumb_height = ((max_visible * 64 / total).max(4)) as i32;
            let thumb_y = HEADER_HEIGHT
                + ((state.book_scroll as i32) * (64 - HEADER_HEIGHT - thumb_height)
                    / ((total - max_visible) as i32));
            sys::canvas_draw_box(canvas, 126, thumb_y, 2, thumb_height as usize);
        }
    }
}

pub fn handle_input(event: &InputEvent, state: &mut AppState) -> bool {
    let filtered_books = get_filtered_books(state.book_filter_idx);
    if filtered_books.is_empty() {
        return false;
    }

    let max_visible = ((64 - HEADER_HEIGHT - 2) / LINE_HEIGHT) as usize;

    // Find the current index of selected_book in filtered_books
    let current_filtered_idx = filtered_books
        .iter()
        .position(|&b| b == state.selected_book)
        .unwrap_or(0);

    match event.key {
        sys::InputKeyUp => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                let next_filtered_idx = if current_filtered_idx > 0 {
                    current_filtered_idx - 1
                } else {
                    filtered_books.len() - 1 // wrap to end
                };
                state.selected_book = filtered_books[next_filtered_idx];

                if next_filtered_idx < state.book_scroll {
                    state.book_scroll = next_filtered_idx;
                } else if next_filtered_idx >= state.book_scroll + max_visible {
                    state.book_scroll = next_filtered_idx.saturating_sub(max_visible - 1);
                }
            }
        }
        sys::InputKeyDown => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                let next_filtered_idx = if current_filtered_idx + 1 < filtered_books.len() {
                    current_filtered_idx + 1
                } else {
                    0 // wrap to start
                };
                state.selected_book = filtered_books[next_filtered_idx];

                if next_filtered_idx >= state.book_scroll + max_visible {
                    state.book_scroll = next_filtered_idx.saturating_sub(max_visible - 1);
                } else if next_filtered_idx < state.book_scroll {
                    state.book_scroll = next_filtered_idx;
                }
            }
        }
        sys::InputKeyLeft => {
            if event.input_type == sys::InputTypeShort {
                state.current_view = AppView::Collection;
            }
        }
        sys::InputKeyRight => {
            if event.input_type == sys::InputTypeShort {
                state.current_view = AppView::BookFilter;
            }
        }
        sys::InputKeyOk => {
            if event.input_type == sys::InputTypeShort {
                state.current_view = AppView::ChapterList;
                state.selected_chapter = 1;
            }
        }
        sys::InputKeyBack => {
            if event.input_type == sys::InputTypeShort {
                if state.book_filter_idx != 0 {
                    state.book_filter_idx = 0;
                    let new_filtered = get_filtered_books(state.book_filter_idx);
                    if !new_filtered.is_empty() {
                        state.selected_book = new_filtered[0];
                        state.book_scroll = 0;
                    }
                } else {
                    return true; // Quit app
                }
            }
        }
        _ => {}
    }
    false
}
