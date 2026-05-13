/// Read/write collection.json for saved passages.

use alloc::string::String;
use alloc::vec::Vec;
use flipperzero_sys as sys;
use crate::models::{Verse, CollectionEntry};

const COLLECTION_PATH: &str = "/ext/apps_data/kindled_spark/collection.json";
const MAX_FILE_SIZE: usize = 16_000;

fn path_to_cstr(path: &str, buf: &mut [u8; 128]) -> Option<*const core::ffi::c_char> {
    let bytes = path.as_bytes();
    if bytes.len() + 1 > buf.len() {
        return None;
    }
    buf[..bytes.len()].copy_from_slice(bytes);
    buf[bytes.len()] = 0;
    Some(buf.as_ptr() as *const core::ffi::c_char)
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

/// Write a minimal JSON collection file.
/// Format: {"version":"kindled-flipper-v1","passages":[{"scripture_ref":"...","scripture_display_ref":"...","scripture_translation":"BSB","scripture_verses":[{"number":1,"text":"..."}],"captured_at":"...","note":""}]}
pub fn save_collection(entries: &[CollectionEntry]) -> bool {
    let mut json = String::with_capacity(4096);
    json.push_str("{\"version\":\"kindled-flipper-v1\",\"passages\":[");
    for (i, entry) in entries.iter().enumerate() {
        if i > 0 { json.push(','); }
        json.push_str("{\"scripture_ref\":\"");
        json.push_str(&entry.scripture_ref);
        json.push_str("\",\"scripture_display_ref\":\"");
        json.push_str(&entry.scripture_display_ref);
        json.push_str("\",\"scripture_translation\":\"");
        json.push_str(&entry.scripture_translation);
        json.push_str("\",\"scripture_verses\":[");
        for (j, verse) in entry.verses.iter().enumerate() {
            if j > 0 { json.push(','); }
            json.push_str("{\"number\":");
            json.push_str(&u16_to_string(verse.number));
            json.push_str(",\"text\":\"");
            // Escape quotes and backslashes in text
            for c in verse.text.chars() {
                match c {
                    '"' => json.push_str("\\\""),
                    '\\' => json.push_str("\\\\"),
                    '\n' => json.push_str("\\n"),
                    _ => json.push(c),
                }
            }
            json.push_str("\"}");
        }
        json.push_str("],\"captured_at\":\"");
        json.push_str(&entry.captured_at);
        json.push_str("\",\"note\":\"");
        json.push_str(&entry.note);
        json.push_str("\"}");
    }
    json.push_str("]}");

    let mut path_buf = [0u8; 128];
    let path_c = match path_to_cstr(COLLECTION_PATH, &mut path_buf) {
        Some(p) => p,
        None => return false,
    };

    unsafe {
        let storage = sys::furi_record_open(c"storage".as_ptr() as *const u8);
        if storage.is_null() { return false; }

        let file = sys::storage_file_alloc(storage as *mut sys::Storage);
        if file.is_null() {
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return false;
        }

        let opened = sys::storage_file_open(file, path_c, sys::FSAM_WRITE, sys::FSOM_OPEN_ALWAYS);
        if !opened {
            sys::storage_file_free(file);
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return false;
        }

        let written = sys::storage_file_write(file, json.as_ptr() as *const core::ffi::c_void, json.len());
        sys::storage_file_close(file);
        sys::storage_file_free(file);
        sys::furi_record_close(c"storage".as_ptr() as *const u8);

        written == json.len()
    }
}

/// Load collection entries from SD card. Returns empty vec if file missing or invalid.
pub fn load_collection() -> Vec<CollectionEntry> {
    let mut path_buf = [0u8; 128];
    let path_c = match path_to_cstr(COLLECTION_PATH, &mut path_buf) {
        Some(p) => p,
        None => return Vec::new(),
    };

    unsafe {
        let storage = sys::furi_record_open(c"storage".as_ptr() as *const u8);
        if storage.is_null() { return Vec::new(); }

        let file = sys::storage_file_alloc(storage as *mut sys::Storage);
        if file.is_null() {
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return Vec::new();
        }

        let opened = sys::storage_file_open(file, path_c, sys::FSAM_READ, sys::FSOM_OPEN_EXISTING);
        if !opened {
            sys::storage_file_free(file);
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return Vec::new();
        }

        let mut buf = [0u8; MAX_FILE_SIZE];
        let read = sys::storage_file_read(file, buf.as_mut_ptr() as *mut core::ffi::c_void, MAX_FILE_SIZE);
        sys::storage_file_close(file);
        sys::storage_file_free(file);
        sys::furi_record_close(c"storage".as_ptr() as *const u8);

        if read == 0 { return Vec::new(); }
        parse_collection_json(&buf[..read])
    }
}

/// Parse collection JSON — minimal scanner for the Kindled schema.
fn parse_collection_json(data: &[u8]) -> Vec<CollectionEntry> {
    let mut entries = Vec::new();
    let mut i = 0;
    let len = data.len();

    while i < len {
        // Look for scripture_ref field
        if let Some(ref_start) = find_key_value(data, i, b"scripture_ref") {
            let ref_val = ref_start;
            i = ref_val.end;

            let display_ref = find_key_value(data, i, b"scripture_display_ref")
                .map(|r| r.to_string(data)).unwrap_or_default();
            let translation = find_key_value(data, i, b"scripture_translation")
                .map(|r| r.to_string(data)).unwrap_or_default();

            // Find verses array
            let mut verses = Vec::new();
            if let Some(verse_start) = find_subsequence(data, i, b"\"verses\":[") {
                let mut vi = verse_start + 10;
                while vi < len {
                    if data[vi] == b']' { break; }
                    if let Some(num_range) = find_key_value(data, vi, b"number") {
                        let num = parse_u16_from_bytes(&data[num_range.start..num_range.end]);
                        vi = num_range.end;
                        if let Some(text_range) = find_key_value(data, vi, b"text") {
                            let text = text_range.to_string(data);
                            verses.push(Verse { number: num, text });
                            vi = text_range.end;
                        }
                    } else {
                        vi += 1;
                    }
                    while vi < len && (data[vi] == b' ' || data[vi] == b'\n' || data[vi] == b',') {
                        vi += 1;
                    }
                }
            }

            let captured_at = find_key_value(data, i, b"captured_at")
                .map(|r| r.to_string(data)).unwrap_or_default();
            let note = find_key_value(data, i, b"note")
                .map(|r| r.to_string(data)).unwrap_or_default();

            entries.push(CollectionEntry {
                scripture_ref: ref_val.to_string(data),
                scripture_display_ref: display_ref,
                scripture_translation: translation,
                verses,
                captured_at,
                note,
            });
        } else {
            i += 1;
        }
    }

    entries
}

struct ByteRange {
    start: usize,
    end: usize,
}

impl ByteRange {
    fn to_string(&self, data: &[u8]) -> String {
        String::from_utf8_lossy(&data[self.start..self.end]).into_owned()
    }
}

fn find_subsequence(data: &[u8], start: usize, needle: &[u8]) -> Option<usize> {
    if needle.is_empty() || start >= data.len() { return None; }
    data[start..].windows(needle.len()).position(|w| w == needle).map(|p| start + p)
}

fn find_key_value(data: &[u8], start: usize, key: &[u8]) -> Option<ByteRange> {
    let key_quoted_len = key.len() + 2; // "key"
    let search_start = start.saturating_sub(1);
    let mut i = search_start;
    while i + key_quoted_len + 2 < data.len() {
        if data[i] == b'"' && &data[i+1..i+1+key.len()] == key && data[i+1+key.len()] == b'"' {
            // Skip past key and colon
            i += key_quoted_len + 1;
            while i < data.len() && (data[i] == b':' || data[i] == b' ' || data[i] == b'\t') {
                i += 1;
            }
            if i >= data.len() { return None; }
            // Extract value
            if data[i] == b'"' {
                i += 1;
                let val_start = i;
                while i < data.len() && data[i] != b'"' {
                    i += 1;
                }
                return Some(ByteRange { start: val_start, end: i });
            } else {
                // Numeric value
                let val_start = i;
                while i < data.len() && data[i].is_ascii_digit() {
                    i += 1;
                }
                return Some(ByteRange { start: val_start, end: i });
            }
        }
        i += 1;
    }
    None
}

fn parse_u16_from_bytes(bytes: &[u8]) -> u16 {
    let mut n = 0u16;
    for &b in bytes {
        if b.is_ascii_digit() {
            n = n * 10 + (b - b'0') as u16;
        }
    }
    n
}
