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
        let current_page = state.scroll_offset / max_visible + 1;
        if total_pages > 1 {
            sys::canvas_set_font(canvas, sys::FontSecondary);
            let page_str = alloc::format!("{}/{}", current_page, total_pages);
            let mut pbuf = [0u8; 8];
            let pb = page_str.as_bytes();
            let plen = pb.len().min(pbuf.len() - 1);
            pbuf[..plen].copy_from_slice(&pb[..plen]);
            pbuf[plen] = 0;
            sys::canvas_draw_str(canvas, 110, 63, pbuf.as_ptr() as *const u8);
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
                sys::canvas_draw_box(canvas, 0, y - 8, 128, 14);
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

pub fn handle_input(event: &InputEvent, state: &mut AppState) -> bool {
    let total_lines = state.lines.len();
    let max_visible = reader_max_visible();
    let max_scroll = total_lines.saturating_sub(max_visible);

    match event.key {
        sys::InputKeyUp => {
            if state.scroll_offset > 0 {
                state.scroll_offset -= 1;
            }
        }
        sys::InputKeyDown => {
            if state.scroll_offset < max_scroll {
                state.scroll_offset += 1;
            }
        }
        sys::InputKeyLeft => {
            if state.scroll_offset >= max_visible {
                state.scroll_offset -= max_visible;
            } else {
                state.scroll_offset = 0;
            }
        }
        sys::InputKeyRight => {
            if state.scroll_offset + max_visible <= max_scroll {
                state.scroll_offset += max_visible;
            } else {
                state.scroll_offset = max_scroll;
            }
        }
        sys::InputKeyOk => {
            if event.input_type == sys::InputTypeLong {
                // Quick save
                do_save(state);
            } else {
                // Open action menu
                state.action_menu_selection = 0;
                state.current_view = AppView::ActionMenu;
            }
        }
        sys::InputKeyBack => {
            state.current_view = AppView::VerseSelect;
        }
        _ => {}
    }
    false
}

pub fn handle_action_input(event: &InputEvent, state: &mut AppState) -> bool {
    match event.key {
        sys::InputKeyUp => {
            if state.action_menu_selection > 0 {
                state.action_menu_selection -= 1;
            }
        }
        sys::InputKeyDown => {
            if state.action_menu_selection < 2 {
                state.action_menu_selection += 1;
            }
        }
        sys::InputKeyOk => match state.action_menu_selection {
            0 => {
                do_save(state);
                state.current_view = AppView::Reader;
            }
            1 => {
                do_nfc_share(state);
                state.current_view = AppView::Reader;
            }
            2 => {
                state.current_view = AppView::Reader;
            }
            _ => {}
        },
        sys::InputKeyBack => {
            state.current_view = AppView::Reader;
        }
        _ => {}
    }
    false
}

fn do_save(state: &mut AppState) {
    if let Some(ref passage) = state.passage {
        let entry = crate::models::CollectionEntry {
            scripture_ref: passage.canonical_ref(),
            scripture_display_ref: passage.display_ref(),
            scripture_translation: String::from("BSB"),
            verses: passage.verses.clone(),
            captured_at: String::from("2026-01-01T00:00:00Z"), // TODO: get real time
            note: String::new(),
        };
        state.collection.push(entry);
        if crate::storage::save_collection(&state.collection) {
            state.set_toast("Saved!");
        } else {
            state.set_toast("Save failed");
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
        let filename = passage.canonical_ref().replace(['.', '-'], "_");
        if crate::nfc_share::write_nfc_file(&filename, &url) {
            state.set_toast("NFC file ready");
        } else {
            state.set_toast("NFC failed");
        }
    }
}
