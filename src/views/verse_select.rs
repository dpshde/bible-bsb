/// Verse selection view — "All" or range (start/end verse).

use alloc::string::String;
use flipperzero_sys as sys;
use crate::books;
use crate::views::{AppState, AppView, InputEvent, VerseSelectMode};

const LINE_H: i32 = 12;
const HEADER_H: i32 = 12;

pub fn draw(canvas: *mut sys::Canvas, state: &AppState) {
    unsafe {
        sys::canvas_set_font(canvas, sys::FontPrimary);

        // Header
        let book = books::OSIS_BOOK_NAMES[state.selected_book];
        let ch = u16_to_string(state.selected_chapter);
        let mut header = [0u8; 48];
        let htext = alloc::format!("{} {}", book, ch);
        let hb = htext.as_bytes();
        let hlen = hb.len().min(header.len() - 1);
        header[..hlen].copy_from_slice(&hb[..hlen]);
        header[hlen] = 0;
        sys::canvas_draw_str(canvas, 2, 10, header.as_ptr() as *const u8);
        sys::canvas_draw_line(canvas, 0, HEADER_H, 128, HEADER_H);

        let max_v = books::max_verse_for_chapter(state.selected_book, state.selected_chapter);
        let actual_max = if max_v > 0 { max_v } else { 40 };

        // Options
        let y1 = HEADER_H + 10;
        let y2 = y1 + LINE_H;
        let y3 = y2 + LINE_H;

        // "All verses" option
        let all_selected = state.verse_select_mode == VerseSelectMode::All;
        if all_selected {
            sys::canvas_draw_box(canvas, 0, y1 - 8, 128, LINE_H as usize);
            sys::canvas_set_color(canvas, sys::ColorWhite);
        }
        sys::canvas_draw_str(canvas, 4, y1, c"All verses".as_ptr() as *const u8);
        if all_selected {
            sys::canvas_set_color(canvas, sys::ColorBlack);
        }

        // Start verse row
        let start_selected = state.verse_select_mode == VerseSelectMode::RangeSelectingStart;
        if start_selected {
            sys::canvas_draw_box(canvas, 0, y2 - 8, 128, LINE_H as usize);
            sys::canvas_set_color(canvas, sys::ColorWhite);
        }
        let mut start_label = [0u8; 32];
        let sl = alloc::format!("Start: {}", u16_to_string(state.selected_start_verse));
        let slb = sl.as_bytes();
        let sllen = slb.len().min(start_label.len() - 1);
        start_label[..sllen].copy_from_slice(&slb[..sllen]);
        start_label[sllen] = 0;
        sys::canvas_draw_str(canvas, 4, y2, start_label.as_ptr() as *const u8);
        if start_selected {
            sys::canvas_set_color(canvas, sys::ColorBlack);
        }

        // End verse row
        let end_selected = state.verse_select_mode == VerseSelectMode::RangeSelectingEnd;
        if end_selected {
            sys::canvas_draw_box(canvas, 0, y3 - 8, 128, LINE_H as usize);
            sys::canvas_set_color(canvas, sys::ColorWhite);
        }
        let end_label = alloc::format!("End: {}", u16_to_string(state.selected_end_verse));
        let mut end_buf = [0u8; 32];
        let eb = end_label.as_bytes();
        let elen = eb.len().min(end_buf.len() - 1);
        end_buf[..elen].copy_from_slice(&eb[..elen]);
        end_buf[elen] = 0;
        sys::canvas_draw_str(canvas, 4, y3, end_buf.as_ptr() as *const u8);
        if end_selected {
            sys::canvas_set_color(canvas, sys::ColorBlack);
        }

        // Hint
        sys::canvas_set_font(canvas, sys::FontSecondary);
        let hint = if state.verse_select_mode == VerseSelectMode::All {
            "OK=read, Back=back"
        } else {
            "Up/Dn=verse, Rgt=next, OK=read"
        };
        let mut hint_buf = [0u8; 48];
        let hbytes = hint.as_bytes();
        let hblen = hbytes.len().min(hint_buf.len() - 1);
        hint_buf[..hblen].copy_from_slice(&hbytes[..hblen]);
        hint_buf[hblen] = 0;
        sys::canvas_draw_str(canvas, 2, 60, hint_buf.as_ptr() as *const u8);
    }
}

pub fn handle_input(event: &InputEvent, state: &mut AppState) -> bool {
    let max_v = books::max_verse_for_chapter(state.selected_book, state.selected_chapter);
    let actual_max = if max_v > 0 { max_v } else { 40 };

    match event.key {
        sys::InputKeyUp => {
            match state.verse_select_mode {
                VerseSelectMode::RangeSelectingStart => {
                    if state.selected_start_verse > 1 {
                        state.selected_start_verse -= 1;
                    }
                }
                VerseSelectMode::RangeSelectingEnd => {
                    if state.selected_end_verse > state.selected_start_verse {
                        state.selected_end_verse -= 1;
                    }
                }
                _ => {}
            }
        }
        sys::InputKeyDown => {
            match state.verse_select_mode {
                VerseSelectMode::RangeSelectingStart => {
                    if state.selected_start_verse < actual_max {
                        state.selected_start_verse += 1;
                        if state.selected_end_verse < state.selected_start_verse {
                            state.selected_end_verse = state.selected_start_verse;
                        }
                    }
                }
                VerseSelectMode::RangeSelectingEnd => {
                    if state.selected_end_verse < actual_max {
                        state.selected_end_verse += 1;
                    }
                }
                _ => {}
            }
        }
        sys::InputKeyLeft => {
            match state.verse_select_mode {
                VerseSelectMode::All => {}
                VerseSelectMode::RangeSelectingEnd => {
                    state.verse_select_mode = VerseSelectMode::RangeSelectingStart;
                }
                VerseSelectMode::RangeSelectingStart => {
                    state.verse_select_mode = VerseSelectMode::All;
                }
            }
        }
        sys::InputKeyRight => {
            match state.verse_select_mode {
                VerseSelectMode::All => {
                    state.verse_select_mode = VerseSelectMode::RangeSelectingStart;
                }
                VerseSelectMode::RangeSelectingStart => {
                    state.verse_select_mode = VerseSelectMode::RangeSelectingEnd;
                }
                VerseSelectMode::RangeSelectingEnd => {}
            }
        }
        sys::InputKeyOk => {
            // Load chapter and go to reader
            let osis = books::OSIS_BOOK_CODES[state.selected_book].to_lowercase();
            let chapter = state.selected_chapter;
            if let Some(verses) = crate::bsb_loader::load_chapter(&osis, chapter) {
                let start_verse = if state.verse_select_mode == VerseSelectMode::All {
                    0
                } else {
                    state.selected_start_verse
                };
                let end_verse = if state.verse_select_mode == VerseSelectMode::All {
                    0
                } else {
                    state.selected_end_verse
                };

                // Filter verses to range if needed
                let filtered: alloc::vec::Vec<crate::models::Verse> = if start_verse > 0 {
                    verses.into_iter()
                        .filter(|v| v.number >= start_verse && v.number <= end_verse)
                        .collect()
                } else {
                    verses
                };

                state.lines = crate::renderer::wrap_verses(&filtered);
                state.passage = Some(crate::models::Passage {
                    book_index: state.selected_book,
                    chapter,
                    start_verse,
                    end_verse,
                    verses: filtered,
                });
                state.scroll_offset = 0;
                state.current_view = AppView::Reader;
            } else {
                state.set_toast("No BSB data");
            }
        }
        sys::InputKeyBack => {
            state.current_view = AppView::ChapterList;
        }
        _ => {}
    }
    false
}

fn u16_to_string(n: u16) -> String {
    if n == 0 { return String::from("0"); }
    let mut buf = [0u8; 6];
    let mut i = 0;
    let mut n = n;
    while n > 0 {
        buf[i] = b'0' + (n % 10) as u8;
        i += 1;
        n /= 10;
    }
    let mut s = String::with_capacity(i);
    for j in (0..i).rev() { s.push(buf[j] as char); }
    s
}
