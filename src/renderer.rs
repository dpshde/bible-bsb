/// Canvas word-wrap & pagination for the 128x64 Flipper Zero screen.

use alloc::format;
use alloc::string::String;
use alloc::vec::Vec;
use flipperzero_sys as sys;

const CHAR_WIDTH: i32 = 6;    // Width of a character in pixels (5x7 font + 1px gap)
const CHAR_HEIGHT: i32 = 8;   // Height of a character in pixels
const SCREEN_WIDTH: i32 = 128;
const SCREEN_HEIGHT: i32 = 64;
const MARGIN_X: i32 = 2;
const MARGIN_Y: i32 = 2;

/// A line of wrapped text ready for rendering.
pub struct Line {
    pub text: String,
    pub is_verse_number: bool,
}

/// Wrap text into lines that fit the screen width.
pub fn wrap_text(text: &str, max_chars: usize) -> Vec<Line> {
    let mut lines = Vec::new();
    let mut current = String::with_capacity(max_chars);

    for word in text.split_whitespace() {
        if current.len() + word.len() + 1 > max_chars {
            if !current.is_empty() {
                lines.push(Line { text: current.clone(), is_verse_number: false });
                current.clear();
            }
        }
        if !current.is_empty() {
            current.push(' ');
        }
        current.push_str(word);
    }

    if !current.is_empty() {
        lines.push(Line { text: current, is_verse_number: false });
    }

    lines
}

/// Wrap verses into displayable lines with verse numbers.
pub fn wrap_verses(verses: &[crate::models::Verse]) -> Vec<Line> {
    let max_chars = ((SCREEN_WIDTH - MARGIN_X * 2) / CHAR_WIDTH) as usize;
    let mut all_lines = Vec::new();

    for verse in verses {
        let num_str = format!("{} ", verse.number);
        let mut verse_lines = wrap_text(&verse.text, max_chars.saturating_sub(num_str.len()));
        if let Some(first) = verse_lines.first_mut() {
            first.text = format!("{}{}", num_str, first.text);
        }
        for line in verse_lines {
            all_lines.push(line);
        }
    }

    all_lines
}

/// Render a page of lines starting at `scroll_offset`.
pub fn render_page(canvas: *mut sys::Canvas, lines: &[Line], scroll_offset: usize) {
    unsafe {
        sys::canvas_set_font(canvas, sys::FontPrimary);
        let max_visible = ((SCREEN_HEIGHT - MARGIN_Y * 2) / CHAR_HEIGHT) as usize;
        let y_start = MARGIN_Y;

        for (i, line) in lines.iter().skip(scroll_offset).take(max_visible).enumerate() {
            let y = y_start + (i as i32 * CHAR_HEIGHT);
            if y + CHAR_HEIGHT > SCREEN_HEIGHT - MARGIN_Y {
                break;
            }
            let mut text_buf = [0u8; 128];
            let bytes = line.text.as_bytes();
            let len = bytes.len().min(text_buf.len() - 1);
            text_buf[..len].copy_from_slice(&bytes[..len]);
            text_buf[len] = 0;
            sys::canvas_draw_str(canvas, MARGIN_X, y + CHAR_HEIGHT - 1, text_buf.as_ptr() as *const u8);
        }
    }
}

/// Calculate total pages given lines and visible lines count.
pub fn total_pages(lines: &[Line]) -> usize {
    let max_visible = ((SCREEN_HEIGHT - MARGIN_Y * 2) / CHAR_HEIGHT) as usize;
    if lines.is_empty() {
        return 1;
    }
    (lines.len() + max_visible - 1) / max_visible
}
