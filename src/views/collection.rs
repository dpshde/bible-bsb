use crate::views::{AppState, AppView, InputEvent};
use alloc::string::String;
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
                c"Back to home".as_ptr() as *const u8,
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

        // Hint bar at bottom
        sys::canvas_set_font(canvas, sys::FontSecondary);
        sys::canvas_draw_str(canvas, 2, 62, c"L=export OK=read".as_ptr() as *const u8);
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
        sys::InputKeyLeft => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeShort {
                if !state.collection.is_empty() {
                    let json = crate::storage::build_kindled_json(&state.collection);
                    state.nfc_url = Some(String::from("Export JSON"));
                    state.nfc_is_export = true;
                    if crate::nfc_share::start_text_emulation(&json) {
                        state.current_view = AppView::NfcShare;
                    } else {
                        state.nfc_url = None;
                        state.nfc_is_export = false;
                        state.set_toast("Export too large");
                    }
                }
            }
        }
        sys::InputKeyOk => {
            if event.input_type == sys::InputTypeLong {
                // Delete selected passage
                if state.collection_scroll < state.collection.len() {
                    state.collection.remove(state.collection_scroll);
                    if !state.collection.is_empty() && state.collection_scroll >= state.collection.len() {
                        state.collection_scroll -= 1;
                    }
                    crate::storage::save_collection(&state.collection);
                    state.set_toast("Deleted");
                }
            } else if event.input_type == sys::InputTypeShort {
                if let Some(entry) = state.collection.get(state.collection_scroll) {
                    let book_index = entry.book_index;
                    let chapter = entry.chapter;
                    let osis_lower = crate::books::OSIS_BOOK_CODES[book_index].to_lowercase();

                    let verses = if let Some(all_verses) = crate::bsb_loader::load_chapter(&osis_lower, chapter) {
                        // Filter to the saved verse range
                        all_verses
                            .into_iter()
                            .filter(|v| v.number >= entry.start_verse && v.number <= entry.end_verse)
                            .collect::<alloc::vec::Vec<_>>()
                    } else {
                        alloc::vec::Vec::new()
                    };

                    state.lines = crate::renderer::wrap_verses(&verses);
                    state.selected_book = book_index;
                    state.selected_chapter = chapter;

                    let start_verse = if verses.is_empty() { 0 } else { verses.first().unwrap().number };
                    let end_verse = if verses.is_empty() { 0 } else { verses.last().unwrap().number };

                    state.passage = Some(crate::models::Passage {
                        book_index,
                        chapter,
                        start_verse,
                        end_verse,
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
