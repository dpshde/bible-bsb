/// NFC Share view — waiting screen while the Flipper emits an NDEF record.
use alloc::string::String;
use flipperzero_sys as sys;

use crate::views::{AppState, AppView, InputEvent};

pub fn draw(canvas: *mut sys::Canvas, state: &AppState) {
    unsafe {
        sys::canvas_clear(canvas);
        sys::canvas_set_font(canvas, sys::FontPrimary);
        if state.nfc_is_export {
            sys::canvas_draw_str(canvas, 2, 10, c"Export NFC".as_ptr() as *const u8);
        } else {
            sys::canvas_draw_str(canvas, 2, 10, c"NFC Share".as_ptr() as *const u8);
        }
        sys::canvas_draw_line(canvas, 0, 12, 128, 12);

        sys::canvas_set_font(canvas, sys::FontSecondary);
        sys::canvas_draw_str(canvas, 2, 24, c"Hold near reader...".as_ptr() as *const u8);

        // Draw animated pulsing dot
        let pulse = (state.toast_timer / 10) % 4;
        let mut dots = String::from("");
        for _ in 0..=pulse {
            dots.push('.');
        }
        let mut dbuf = [0u8; 8];
        let db = dots.as_bytes();
        let dlen = db.len().min(dbuf.len() - 1);
        dbuf[..dlen].copy_from_slice(&db[..dlen]);
        dbuf[dlen] = 0;
        sys::canvas_draw_str(canvas, 100, 24, dbuf.as_ptr() as *const u8);

        // Show URL or export label (truncated if needed)
        if let Some(ref url) = state.nfc_url {
            sys::canvas_set_font(canvas, sys::FontSecondary);
            let display = if state.nfc_is_export {
                String::from("Export JSON")
            } else if url.len() > 28 {
                let mut s = String::from(&url[..25]);
                s.push_str("...");
                s
            } else {
                url.clone()
            };
            let mut ubuf = [0u8; 48];
            let ub = display.as_bytes();
            let ulen = ub.len().min(ubuf.len() - 1);
            ubuf[..ulen].copy_from_slice(&ub[..ulen]);
            ubuf[ulen] = 0;
            sys::canvas_draw_str(canvas, 2, 38, ubuf.as_ptr() as *const u8);
        }

        // Instructions at bottom
        sys::canvas_set_font(canvas, sys::FontSecondary);
        sys::canvas_draw_str(canvas, 2, 62, c"Back to cancel".as_ptr() as *const u8);
    }
}

pub fn handle_input(event: &InputEvent, state: &mut AppState) -> bool {
    if event.key == sys::InputKeyBack && event.input_type == sys::InputTypeShort {
        // Stop NFC emission and return
        crate::nfc_share::stop_emulation();
        state.nfc_emitting = false;
        state.nfc_url = None;
        if state.nfc_is_export {
            state.nfc_is_export = false;
            state.current_view = AppView::Collection;
        } else {
            state.current_view = AppView::Reader;
        }
    }
    false
}
