use crate::views::{AppState, AppView, InputEvent};
use flipperzero_sys as sys;

const COLS: usize = 5;
const CELL_W: i32 = 25;
const CELL_H: i32 = 14;

pub const OPTIONS: [&str; 22] = [
    "All", "A", "C", "D", "E", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "R", "S", "T",
    "Z", "1", "2", "3",
];

pub fn draw(canvas: *mut sys::Canvas, state: &AppState) {
    unsafe {
        sys::canvas_clear(canvas);
        sys::canvas_set_font(canvas, sys::FontPrimary);

        sys::canvas_draw_str(canvas, 2, 10, c"< Select Filter".as_ptr() as *const u8);
        sys::canvas_draw_line(canvas, 0, 12, 128, 12);

        let selected_row = state.book_filter_idx / COLS;
        let max_visible_rows = 3;
        let start_row = if selected_row >= max_visible_rows {
            selected_row - max_visible_rows + 1
        } else {
            0
        };

        for i in 0..OPTIONS.len() {
            let row = i / COLS;
            let col = i % COLS;

            if row < start_row || row >= start_row + max_visible_rows {
                continue;
            }

            let display_row = row - start_row;
            let x = 2 + (col as i32 * CELL_W);
            let y = 14 + (display_row as i32 * CELL_H);
            let is_selected = i == state.book_filter_idx;

            if is_selected {
                sys::canvas_draw_box(canvas, x, y, CELL_W as usize, CELL_H as usize);
                sys::canvas_set_color(canvas, sys::ColorWhite);
            }

            let opt = OPTIONS[i];
            let mut buf = [0u8; 8];
            let bytes = opt.as_bytes();
            let len = bytes.len().min(buf.len() - 1);
            buf[..len].copy_from_slice(&bytes[..len]);
            buf[len] = 0;

            sys::canvas_draw_str(canvas, x + 4, y + 11, buf.as_ptr() as *const u8);

            if is_selected {
                sys::canvas_set_color(canvas, sys::ColorBlack);
            }
        }

        // Scroll indicator
        let total_rows = (OPTIONS.len() + COLS - 1) / COLS;
        if total_rows > max_visible_rows {
            let thumb_height = ((max_visible_rows * 50) / total_rows).max(4) as i32;
            let thumb_y = 14
                + (start_row as i32 * (50 - thumb_height) / (total_rows - max_visible_rows) as i32);
            sys::canvas_draw_box(canvas, 126, thumb_y, 2, thumb_height as usize);
        }
    }
}

pub fn handle_input(event: &InputEvent, state: &mut AppState) -> bool {
    let total = OPTIONS.len();
    let cols = COLS;

    match event.key {
        sys::InputKeyUp => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.book_filter_idx >= cols {
                    state.book_filter_idx -= cols;
                }
            }
        }
        sys::InputKeyDown => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.book_filter_idx + cols < total {
                    state.book_filter_idx += cols;
                } else if state.book_filter_idx < total - 1 {
                    // snap to last item if moving down from the row above the last partial row
                    // Not strictly necessary, but helpful
                    state.book_filter_idx = total - 1;
                }
            }
        }
        sys::InputKeyLeft => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.book_filter_idx == 0 {
                    // On "All", left arrow goes back to book list
                    state.current_view = AppView::BookList;
                } else {
                    state.book_filter_idx -= 1;
                }
            }
        }
        sys::InputKeyRight => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.book_filter_idx + 1 < total {
                    state.book_filter_idx += 1;
                }
            }
        }
        sys::InputKeyOk | sys::InputKeyBack => {
            if event.input_type == sys::InputTypeShort {
                state.current_view = AppView::BookList;
                let new_filtered =
                    crate::views::book_list::get_filtered_books(state.book_filter_idx);
                if !new_filtered.is_empty() {
                    state.selected_book = new_filtered[0];
                    state.book_scroll = 0;
                }
            }
        }
        _ => {}
    }
    false
}
