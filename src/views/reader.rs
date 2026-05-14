use crate::books;
use crate::views::{AppState, AppView, InputEvent};
/// Reader view — paginated verse text with action menu and quick-save.
use alloc::string::String;
use flipperzero_sys as sys;

pub fn draw(canvas: *mut sys::Canvas, state: &AppState) {
    unsafe {
        sys::canvas_clear(canvas);

        // Show passage reference header
        if let Some(ref passage) = state.passage {
            sys::canvas_set_font(canvas, sys::FontSecondary);
            let ref_str = passage.display_ref();
            let mut buf = [0u8; 48];
            let bytes = ref_str.as_bytes();
            let len = bytes.len().min(buf.len() - 1);
            buf[..len].copy_from_slice(&bytes[..len]);
            buf[len] = 0;
            sys::canvas_draw_str(canvas, 2, 8, buf.as_ptr() as *const u8);
            sys::canvas_draw_line(canvas, 0, 10, 128, 10);
        }

        // Render text below header with top padding (header line at y=10, padding to y=16)
        crate::renderer::render_page(canvas, &state.lines, state.scroll_offset, 16);

        // Page indicator
        let total_pages = crate::renderer::total_pages(&state.lines, 16);
        let max_visible = ((64 - 16 - 2) / crate::renderer::LINE_HEIGHT) as usize;
        let current_page = if state.scroll_offset + max_visible >= state.lines.len() {
            total_pages
        } else {
            state.scroll_offset / max_visible + 1
        };
        if total_pages > 1 {
            sys::canvas_set_font(canvas, sys::FontSecondary);
            let page_str = alloc::format!("{}/{}", current_page, total_pages);
            let mut pbuf = [0u8; 16];
            let pb = page_str.as_bytes();
            let plen = pb.len().min(pbuf.len() - 1);
            pbuf[..plen].copy_from_slice(&pb[..plen]);
            pbuf[plen] = 0;

            let width = sys::canvas_string_width(canvas, pbuf.as_ptr() as *const core::ffi::c_char);
            let x = 128 - (width as i32) - 2;
            sys::canvas_draw_str(canvas, x, 63, pbuf.as_ptr() as *const u8);
        }
        // Toast
        if let Some(ref msg) = state.toast_message {
            sys::canvas_set_font(canvas, sys::FontSecondary);
            // Draw toast background
            let msg_len = msg.len().min(20);
            let toast_w = (msg_len as i32 * 5) + 4;
            let toast_x = (128 - toast_w) / 2;
            sys::canvas_draw_box(canvas, toast_x, 24, toast_w as usize, 14);
            sys::canvas_set_color(canvas, sys::ColorWhite);
            let mut tbuf = [0u8; 32];
            let tb = msg.as_bytes();
            let tlen = tb.len().min(tbuf.len() - 1);
            tbuf[..tlen].copy_from_slice(&tb[..tlen]);
            tbuf[tlen] = 0;
            sys::canvas_draw_str(canvas, toast_x + 2, 34, tbuf.as_ptr() as *const u8);
            sys::canvas_set_color(canvas, sys::ColorBlack);
        }
    }
}

pub fn draw_action_menu(canvas: *mut sys::Canvas, state: &AppState) {
    unsafe {
        sys::canvas_clear(canvas);
        sys::canvas_set_font(canvas, sys::FontPrimary);
        sys::canvas_draw_str(canvas, 2, 10, c"Menu".as_ptr() as *const u8);
        sys::canvas_draw_line(canvas, 0, 12, 128, 12);

        let items = ["Save to collection", "Share via NFC", "Back to reading"];
        for (i, item) in items.iter().enumerate() {
            let y = 24 + (i as i32 * 14);
            let is_selected = i == state.action_menu_selection;
            if is_selected {
                sys::canvas_draw_box(canvas, 0, y - 11, 128, 14);
                sys::canvas_set_color(canvas, sys::ColorWhite);
            }
            let mut ibuf = [0u8; 32];
            let ib = item.as_bytes();
            let ilen = ib.len().min(ibuf.len() - 1);
            ibuf[..ilen].copy_from_slice(&ib[..ilen]);
            ibuf[ilen] = 0;
            sys::canvas_draw_str(canvas, 4, y, ibuf.as_ptr() as *const u8);
            if is_selected {
                sys::canvas_set_color(canvas, sys::ColorBlack);
            }
        }
    }
}

fn reader_max_visible() -> usize {
    ((64 - 16 - 2) / crate::renderer::LINE_HEIGHT) as usize
}

fn next_verse_offset(lines: &[crate::renderer::Line], current: usize) -> Option<usize> {
    let current_verse = lines.get(current)?.verse_number;
    for (i, line) in lines.iter().enumerate().skip(current + 1) {
        if line.verse_number > current_verse {
            return Some(i);
        }
    }
    None
}

fn prev_verse_offset(lines: &[crate::renderer::Line], current: usize) -> Option<usize> {
    let current_verse = lines.get(current)?.verse_number;
    let is_first = lines.get(current)?.is_verse_number;

    if !is_first {
        lines.iter().position(|l| l.verse_number == current_verse && l.is_verse_number)
    } else {
        let mut prev_verse: u16 = 0;
        for line in lines[..current].iter().rev() {
            if line.verse_number < current_verse {
                prev_verse = line.verse_number;
                break;
            }
        }
        if prev_verse == 0 {
            Some(0)
        } else {
            lines.iter().position(|l| l.verse_number == prev_verse && l.is_verse_number)
        }
    }
}

pub fn handle_input(event: &InputEvent, state: &mut AppState) -> bool {
    let total_lines = state.lines.len();
    let max_visible = reader_max_visible();
    let max_scroll = total_lines.saturating_sub(max_visible);

    match event.key {
        sys::InputKeyUp => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if let Some(new_offset) = prev_verse_offset(&state.lines, state.scroll_offset) {
                    state.scroll_offset = new_offset;
                }
            }
        }
        sys::InputKeyDown => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if let Some(new_offset) = next_verse_offset(&state.lines, state.scroll_offset) {
                    if new_offset <= max_scroll {
                        state.scroll_offset = new_offset;
                    } else {
                        state.scroll_offset = max_scroll;
                    }
                }
            }
        }
        sys::InputKeyLeft => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.scroll_offset > 0 {
                    state.scroll_offset -= 1;
                }
            }
        }
        sys::InputKeyRight => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.scroll_offset < max_scroll {
                    state.scroll_offset += 1;
                }
            }
        }
        sys::InputKeyOk => {
            if event.input_type == sys::InputTypeLong {
                // Quick save
                do_save(state);
            } else if event.input_type == sys::InputTypeShort {
                // Open action menu
                state.action_menu_selection = 0;
                state.current_view = AppView::ActionMenu;
            }
        }
        sys::InputKeyBack => {
            if event.input_type == sys::InputTypeShort {
                if state.reader_came_from_collection {
                    state.current_view = AppView::Collection;
                } else {
                    state.current_view = AppView::VerseSelect;
                }
            }
        }
        _ => {}
    }
    false
}

pub fn handle_action_input(event: &InputEvent, state: &mut AppState) -> bool {
    match event.key {
        sys::InputKeyUp => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.action_menu_selection > 0 {
                    state.action_menu_selection -= 1;
                }
            }
        }
        sys::InputKeyDown => {
            if event.input_type == sys::InputTypePress || event.input_type == sys::InputTypeRepeat {
                if state.action_menu_selection < 2 {
                    state.action_menu_selection += 1;
                }
            }
        }
        sys::InputKeyOk => {
            if event.input_type == sys::InputTypeShort {
                match state.action_menu_selection {
                    0 => {
                        do_save(state);
                        state.current_view = AppView::Reader;
                    }
                    1 => {
                        do_nfc_share(state);
                        // do_nfc_share transitions to NfcShare or shows a toast and stays
                    }
                    2 => {
                        state.current_view = AppView::Reader;
                    }
                    _ => {}
                }
            }
        }
        sys::InputKeyBack => {
            if event.input_type == sys::InputTypeShort {
                state.current_view = AppView::Reader;
            }
        }
        _ => {}
    }
    false
}

fn do_save(state: &mut AppState) {
    if let Some(ref passage) = state.passage {
        // Free reader heap before loading collection to avoid fragmentation OOM.
        // The lines will be reloaded from SD after saving.
        let saved_scroll = state.scroll_offset;
        state.lines.clear();

        if !state.collection_loaded {
            state.collection = crate::storage::load_collection();
            state.collection_loaded = true;
        }
        let ref_str = passage.canonical_ref();
        // Idempotent: skip if already saved
        if state.collection.iter().any(|e| e.scripture_ref == ref_str) {
            // Reload lines before returning so the screen isn't blank
            reload_lines(state);
            state.scroll_offset = saved_scroll;
            state.set_toast("Already saved");
            return;
        }
        let entry = crate::models::CollectionEntry {
            scripture_ref: ref_str,
            scripture_display_ref: passage.display_ref(),
            scripture_translation: String::from("BSB"),
            book_index: passage.book_index,
            chapter: passage.chapter,
            start_verse: passage.start_verse,
            end_verse: passage.end_verse,
            captured_at: String::from("2026-01-01T00:00:00Z"), // TODO: get real time
            note: String::new(),
        };
        state.collection.push(entry);
        let ok = crate::storage::save_collection(&state.collection);

        // Reload lines from SD so the reader isn't blank
        reload_lines(state);
        state.scroll_offset = saved_scroll;

        if ok {
            state.set_toast("Saved!");
        } else {
            state.set_toast("Save failed");
        }
    }
}

fn reload_lines(state: &mut AppState) {
    if let Some(ref passage) = state.passage {
        let osis = crate::books::OSIS_BOOK_CODES[passage.book_index].to_lowercase();
        if let Some(all_verses) = crate::bsb_loader::load_chapter(&osis, passage.chapter) {
            let filtered: alloc::vec::Vec<crate::models::Verse> = if passage.start_verse > 0 {
                all_verses
                    .into_iter()
                    .filter(|v| {
                        v.number >= passage.start_verse && v.number <= passage.end_verse
                    })
                    .collect()
            } else {
                all_verses
            };
            state.lines = crate::renderer::wrap_verses(&filtered);
        }
    }
}

fn do_nfc_share(state: &mut AppState) {
    if let Some(ref passage) = state.passage {
        let url = crate::route_url::build_url(
            books::OSIS_BOOK_CODES[passage.book_index],
            passage.chapter,
            passage.start_verse,
            passage.end_verse,
        );
        state.nfc_url = Some(url.clone());
        state.nfc_emitting = true;
        if crate::nfc_share::start_emulation(&url) {
            state.current_view = AppView::NfcShare;
        } else {
            state.nfc_url = None;
            state.nfc_emitting = false;
            state.set_toast("NFC failed");
        }
    }
}
