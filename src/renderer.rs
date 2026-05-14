/// Canvas word-wrap & pagination for the 128x64 Flipper Zero screen.
use alloc::format;
use alloc::string::String;
use alloc::vec::Vec;
use flipperzero_sys as sys;

const CHAR_WIDTH: i32 = 6; // Width of a character in pixels (5x7 font + 1px gap)
const CHAR_HEIGHT: i32 = 8; // Height of a character in pixels
pub const LINE_HEIGHT: i32 = 12; // CHAR_HEIGHT + 4px inter-line spacing for readability
const SCREEN_WIDTH: i32 = 128;
const SCREEN_HEIGHT: i32 = 64;
const MARGIN_X: i32 = 2;
const MARGIN_Y: i32 = 2;

/// A line of wrapped text ready for rendering.
pub struct Line {
    pub text: String,
    pub is_verse_number: bool,
    pub verse_number: u16,
}

/// Wrap text into lines that fit the screen width.
pub fn wrap_text(text: &str, max_chars: usize) -> Vec<Line> {
    let mut lines = Vec::new();
    let mut current = String::with_capacity(max_chars);

    for word in text.split_whitespace() {
        if current.len() + word.len() + 1 > max_chars && !current.is_empty() {
            lines.push(Line {
                text: current.clone(),
                is_verse_number: false,
                verse_number: 0,
            });
            current.clear();
        }
        if !current.is_empty() {
            current.push(' ');
        }
        current.push_str(word);
    }

    if !current.is_empty() {
        lines.push(Line {
            text: current,
            is_verse_number: false,
            verse_number: 0,
        });
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
            first.is_verse_number = true;
        }
        for line in &mut verse_lines {
            line.verse_number = verse.number;
        }
        for line in verse_lines {
            all_lines.push(line);
        }
    }

    all_lines
}

/// Render a page of lines starting at `scroll_offset`.
/// `y_offset` is the top pixel where text should begin (e.g. below a header).
pub fn render_page(canvas: *mut sys::Canvas, lines: &[Line], scroll_offset: usize, y_offset: i32) {
    unsafe {
        sys::canvas_set_font(canvas, sys::FontPrimary);
        let max_visible = ((SCREEN_HEIGHT - y_offset - MARGIN_Y) / LINE_HEIGHT) as usize;
        let y_start = y_offset;

        for (i, line) in lines
            .iter()
            .skip(scroll_offset)
            .take(max_visible)
            .enumerate()
        {
            let y = y_start + (i as i32 * LINE_HEIGHT);
            if y + LINE_HEIGHT > SCREEN_HEIGHT - MARGIN_Y {
                break;
            }
            let mut text_buf = [0u8; 128];
            let bytes = line.text.as_bytes();
            let len = bytes.len().min(text_buf.len() - 1);
            text_buf[..len].copy_from_slice(&bytes[..len]);
            text_buf[len] = 0;
            sys::canvas_draw_str(
                canvas,
                MARGIN_X,
                y + CHAR_HEIGHT - 1,
                text_buf.as_ptr() as *const u8,
            );
        }
    }
}

/// Calculate total pages given lines and visible lines count.
/// `y_offset` is the top pixel where text begins (e.g. below a header).
pub fn total_pages(lines: &[Line], y_offset: i32) -> usize {
    let max_visible = ((SCREEN_HEIGHT - y_offset - MARGIN_Y) / LINE_HEIGHT) as usize;
    if lines.is_empty() || max_visible == 0 {
        return 1;
    }
    lines.len().div_ceil(max_visible)
}
