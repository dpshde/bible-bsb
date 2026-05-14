use crate::views::{AppState, AppView, InputEvent};
use flipperzero_sys as sys;

const LINE_H: i32 = 12;
const HEADER_H: i32 = 12;

pub fn draw(canvas: *mut sys::Canvas, state: &AppState) {
    unsafe {
        sys::canvas_set_font(canvas, sys::FontPrimary);
        sys::canvas_draw_str(canvas, 2, 10, c"Collection >".as_ptr() as *const u8);
        sys::canvas_draw_line(canvas, 0, HEADER_H, 128, HEADER_H);

        if state.collection.is_empty() {
            sys::canvas_set_font(canvas, sys::FontSecondary);
            sys::canvas_draw_str(canvas, 4, 30, c"No saved passages".as_ptr() as *const u8);
            sys::canvas_draw_str(
                canvas,
                4,
                44,
                c"OK to read, Back to home".as_ptr() as *const u8,
            );
            return;
        }

        let max_visible = ((64 - HEADER_H - 4) / LINE_H) as usize;
        let start = state.collection_scroll;

        for i in 0..max_visible {
            let idx = start + i;
            if idx >= state.collection.len() {
                break;
            }

            let y = HEADER_H + 4 + (i as i32 * LINE_H) + 8;
            let entry = &state.collection[idx];
            let is_selected = idx == state.collection_scroll; // simple: scroll = selection

            if is_selected {
                sys::canvas_draw_box(canvas, 0, y - 10, 128, LINE_H as usize);
                sys::canvas_set_color(canvas, sys::ColorWhite);
            }

            let ref_str = &entry.scripture_display_ref;
            let mut buf = [0u8; 32];
            let bytes = ref_str.as_bytes();
            let len = bytes.len().min(buf.len() - 1);
            buf[..len].copy_from_slice(&bytes[..len]);
            buf[len] = 0;
            sys::canvas_draw_str(canvas, 4, y, buf.as_ptr() as *const u8);

            if is_selected {
                sys::canvas_set_color(canvas, sys::ColorBlack);
            }
        }
    }
}

pub fn handle_input(event: &InputEvent, state: &mut AppState) -> bool {
    let _max_visible = ((64 - HEADER_H - 2) / LINE_H) as usize;

    match event.key {
        sys::InputKeyUp => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.collection_scroll > 0 {
                    state.collection_scroll -= 1;
                }
            }
        }
        sys::InputKeyDown => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.collection_scroll + 1 < state.collection.len() {
                    state.collection_scroll += 1;
                }
            }
        }
        sys::InputKeyRight => {
            if event.input_type == sys::InputTypeShort {
                state.current_view = AppView::BookList;
            }
        }
        sys::InputKeyOk => {
            if event.input_type == sys::InputTypeShort {
                if let Some(entry) = state.collection.get(state.collection_scroll) {
                    state.lines = crate::renderer::wrap_verses(&entry.verses);
                    let ref_parts: alloc::vec::Vec<&str> = entry.scripture_ref.split('.').collect();
                    let mut book_index = 0;
                    if let Some(code) = ref_parts.first() {
                        for (i, &book_code) in crate::books::OSIS_BOOK_CODES.iter().enumerate() {
                            if book_code.eq_ignore_ascii_case(code) {
                                book_index = i;
                                break;
                            }
                        }
                    }

                    let chapter = if ref_parts.len() > 1 {
                        ref_parts[1]
                            .split('-')
                            .next()
                            .unwrap_or("1")
                            .parse()
                            .unwrap_or(1)
                    } else {
                        1
                    };

                    let start_verse = entry.verses.first().map(|v| v.number).unwrap_or(0);
                    let end_verse = entry.verses.last().map(|v| v.number).unwrap_or(0);

                    state.selected_book = book_index;
                    state.selected_chapter = chapter;

                    state.passage = Some(crate::models::Passage {
                        book_index,
                        chapter,
                        start_verse,
                        end_verse,
                        verses: entry.verses.clone(),
                    });

                    state.scroll_offset = 0;
                    state.reader_came_from_collection = true;
                    state.current_view = AppView::Reader;
                }
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
