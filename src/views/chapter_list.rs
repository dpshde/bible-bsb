use crate::books;
use crate::views::{AppState, AppView, InputEvent};
/// Chapter list view — grid of chapters for the selected book.
use flipperzero_sys as sys;

const COLS: usize = 5;
const CELL_W: i32 = 24;
const CELL_H: i32 = 14;
const HEADER_H: i32 = 12;

pub fn draw(canvas: *mut sys::Canvas, state: &AppState) {
    unsafe {
        sys::canvas_set_font(canvas, sys::FontPrimary);

        // Header: Book name
        let book_name = books::OSIS_BOOK_NAMES[state.selected_book];
        let mut buf = [0u8; 32];
        let bytes = book_name.as_bytes();
        let len = bytes.len().min(buf.len() - 1);
        buf[..len].copy_from_slice(&bytes[..len]);
        buf[len] = 0;
        sys::canvas_draw_str(canvas, 2, 10, buf.as_ptr() as *const u8);
        sys::canvas_draw_line(canvas, 0, HEADER_H, 128, HEADER_H);

        let max_chapter = books::BOOK_CHAPTER_COUNTS[state.selected_book];
        let total_rows = (max_chapter as usize).div_ceil(COLS).max(1);

        let selected_row = (state.selected_chapter as usize - 1) / COLS;
        let max_visible_rows = 3;
        let start_row = if selected_row >= max_visible_rows {
            selected_row - max_visible_rows + 1
        } else {
            0
        };

        for row in start_row..(start_row + max_visible_rows).min(total_rows) {
            for col in 0..COLS {
                let chapter_num = row * COLS + col + 1;
                if chapter_num > max_chapter as usize {
                    break;
                }

                let display_row = row - start_row;
                let x = 4 + (col as i32 * CELL_W);
                let y = HEADER_H + 4 + (display_row as i32 * CELL_H);
                let is_selected = chapter_num == state.selected_chapter as usize;

                if is_selected {
                    sys::canvas_draw_box(
                        canvas,
                        x,
                        y,
                        (CELL_W - 2) as usize,
                        (CELL_H - 2) as usize,
                    );
                    sys::canvas_set_color(canvas, sys::ColorWhite);
                }

                let num_str = u16_to_string(chapter_num as u16);
                let mut num_buf = [0u8; 4];
                let nb = num_str.as_bytes();
                let nlen = nb.len().min(num_buf.len() - 1);
                num_buf[..nlen].copy_from_slice(&nb[..nlen]);
                num_buf[nlen] = 0;
                sys::canvas_draw_str(canvas, x + 4, y + 10, num_buf.as_ptr() as *const u8);

                if is_selected {
                    sys::canvas_set_color(canvas, sys::ColorBlack);
                }
            }
        }

        // Scroll indicator
        if total_rows > max_visible_rows {
            let thumb_height = ((max_visible_rows * 50) / total_rows).max(4) as i32;
            let thumb_y = 14
                + (start_row as i32 * (50 - thumb_height) / (total_rows - max_visible_rows) as i32);
            sys::canvas_draw_box(canvas, 126, thumb_y, 2, thumb_height as usize);
        }
    }
}

pub fn handle_input(event: &InputEvent, state: &mut AppState) -> bool {
    let max_chapter = books::BOOK_CHAPTER_COUNTS[state.selected_book];
    let cols = COLS as u16;

    match event.key {
        sys::InputKeyUp => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.selected_chapter > cols {
                    state.selected_chapter -= cols;
                }
            }
        }
        sys::InputKeyDown => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.selected_chapter + cols <= max_chapter {
                    state.selected_chapter += cols;
                } else if state.selected_chapter < max_chapter {
                    state.selected_chapter = max_chapter;
                }
            }
        }
        sys::InputKeyLeft => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.selected_chapter > 1 {
                    state.selected_chapter -= 1;
                }
            }
        }
        sys::InputKeyRight => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.selected_chapter < max_chapter {
                    state.selected_chapter += 1;
                }
            }
        }
        sys::InputKeyOk => {
            if event.input_type == sys::InputTypeShort {
                state.current_view = AppView::VerseSelect;
                state.verse_select_mode = crate::views::VerseSelectMode::All;
                state.selected_start_verse = 1;
                state.selected_end_verse = 1;
            }
        }
        sys::InputKeyBack => {
            if event.input_type == sys::InputTypeShort {
                state.current_view = AppView::BookList;
            }
        }
        _ => {}
    }
    false
}

fn u16_to_string(n: u16) -> &'static str {
    // Small static lookup for chapter numbers 1-150
    const NUMS: [&str; 151] = [
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16",
        "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31",
        "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46",
        "47", "48", "49", "50", "51", "52", "53", "54", "55", "56", "57", "58", "59", "60", "61",
        "62", "63", "64", "65", "66", "67", "68", "69", "70", "71", "72", "73", "74", "75", "76",
        "77", "78", "79", "80", "81", "82", "83", "84", "85", "86", "87", "88", "89", "90", "91",
        "92", "93", "94", "95", "96", "97", "98", "99", "100", "101", "102", "103", "104", "105",
        "106", "107", "108", "109", "110", "111", "112", "113", "114", "115", "116", "117", "118",
        "119", "120", "121", "122", "123", "124", "125", "126", "127", "128", "129", "130", "131",
        "132", "133", "134", "135", "136", "137", "138", "139", "140", "141", "142", "143", "144",
        "145", "146", "147", "148", "149", "150",
    ];
    NUMS.get(n as usize).copied().unwrap_or("?")
}
