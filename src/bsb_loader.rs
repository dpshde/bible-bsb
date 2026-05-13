/// Minimal SD-card BSB chapter loader with a tiny no-alloc JSON verse extractor.

use alloc::string::String;
use alloc::vec::Vec;
use flipperzero_sys as sys;
use crate::models::Verse;

const BSB_BASE: &str = "/ext/apps_data/kindled_spark/bsb";
const MAX_FILE_SIZE: usize = 64_000;

/// Build the file path: /ext/apps_data/kindled_spark/bsb/{osis_lower}/{chapter}.json
fn chapter_path(osis_lower: &str, chapter: u16) -> String {
    let mut s = String::with_capacity(80);
    s.push_str(BSB_BASE);
    s.push('/');
    s.push_str(osis_lower);
    s.push('/');
    s.push_str(&u16_to_string(chapter));
    s.push_str(".json");
    s
}

fn u16_to_string(n: u16) -> String {
    if n == 0 {
        return String::from("0");
    }
    let mut buf = [0u8; 6];
    let mut i = 0;
    let mut n = n;
    while n > 0 {
        buf[i] = b'0' + (n % 10) as u8;
        i += 1;
        n /= 10;
    }
    let mut s = String::with_capacity(i);
    for j in (0..i).rev() {
        s.push(buf[j] as char);
    }
    s
}

/// Extract verses from a minimal JSON blob like {"verses":[{"n":1,"t":"..."},...]}
/// This is a tiny state-machine scanner. No heap allocations during parse except output Vec.
pub fn parse_verses_from_json(data: &[u8]) -> Vec<Verse> {
    let mut verses = Vec::new();
    let mut i = 0;
    let len = data.len();

    while i < len {
        // Look for '"n":'
        if i + 4 < len && data[i] == b'"' && data[i + 1] == b'n' && data[i + 2] == b'"' {
            i += 3;
            // Skip to colon
            while i < len && data[i] != b':' {
                i += 1;
            }
            if i >= len {
                break;
            }
            i += 1; // skip colon
            // Skip whitespace
            while i < len && (data[i] == b' ' || data[i] == b'\t') {
                i += 1;
            }
            // Parse number
            let mut number: u16 = 0;
            while i < len && data[i].is_ascii_digit() {
                number = number * 10 + (data[i] - b'0') as u16;
                i += 1;
            }

            // Now look for '"t":"'
            while i < len {
                if i + 4 < len && data[i] == b'"' && data[i + 1] == b't' && data[i + 2] == b'"' {
                    i += 3;
                    while i < len && data[i] != b':' {
                        i += 1;
                    }
                    if i >= len {
                        break;
                    }
                    i += 1;
                    while i < len && (data[i] == b' ' || data[i] == b'\t') {
                        i += 1;
                    }
                    // Expect opening quote
                    if i < len && data[i] == b'"' {
                        i += 1;
                        let start = i;
                        // Read until unescaped closing quote
                        while i < len && data[i] != b'"' {
                            i += 1;
                        }
                        let text_bytes = &data[start..i];
                        let text = String::from_utf8_lossy(text_bytes);
                        // Truncate to 512 chars max
                        let text = if text.len() > 512 {
                            text.chars().take(512).collect::<String>()
                        } else {
                            text.into_owned()
                        };
                        verses.push(Verse { number, text });
                    }
                    break;
                }
                i += 1;
            }
        } else {
            i += 1;
        }
    }

    verses
}

/// Build a null-terminated path in a fixed-size buffer (no-alloc)
fn path_to_cstr(path: &str, buf: &mut [u8; 128]) -> Option<*const core::ffi::c_char> {
    let bytes = path.as_bytes();
    if bytes.len() + 1 > buf.len() {
        return None;
    }
    buf[..bytes.len()].copy_from_slice(bytes);
    buf[bytes.len()] = 0;
    Some(buf.as_ptr() as *const core::ffi::c_char)
}

/// Load verses for a given book (by OSIS code, lowercase) and chapter from SD card.
pub fn load_chapter(osis_lower: &str, chapter: u16) -> Option<Vec<Verse>> {
    let path = chapter_path(osis_lower, chapter);
    let mut path_buf = [0u8; 128];
    let path_c = path_to_cstr(&path, &mut path_buf)?;

    unsafe {
        let storage = sys::furi_record_open(c"storage".as_ptr() as *const u8);
        if storage.is_null() {
            return None;
        }

        let file = sys::storage_file_alloc(storage as *mut sys::Storage);
        if file.is_null() {
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return None;
        }

        let opened = sys::storage_file_open(
            file,
            path_c,
            sys::FSAM_READ,
            sys::FSOM_OPEN_EXISTING,
        );

        if !opened {
            sys::storage_file_free(file);
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return None;
        }

        let mut buf = [0u8; MAX_FILE_SIZE];
        let read = sys::storage_file_read(file, buf.as_mut_ptr() as *mut core::ffi::c_void, MAX_FILE_SIZE);
        sys::storage_file_close(file);
        sys::storage_file_free(file);
        sys::furi_record_close(c"storage".as_ptr() as *const u8);

        if read == 0 {
            return None;
        }

        let data = &buf[..read];
        Some(parse_verses_from_json(data))
    }
}
