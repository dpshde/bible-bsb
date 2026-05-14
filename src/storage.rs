use crate::models::{CollectionEntry, Verse};
/// Read/write collection.json for saved passages.
use alloc::string::String;
use alloc::vec::Vec;
use flipperzero_sys as sys;

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

/// Streaming JSON writer that avoids heap allocations.
/// Uses a fixed 512-byte buffer and writes chunks directly to the file.
struct JsonWriter {
    file: *mut sys::File,
    buf: [u8; 512],
    pos: usize,
    total_written: usize,
    failed: bool,
}

impl JsonWriter {
    fn new(file: *mut sys::File) -> Self {
        Self {
            file,
            buf: [0; 512],
            pos: 0,
            total_written: 0,
            failed: false,
        }
    }

    fn flush(&mut self) {
        if self.pos == 0 || self.failed {
            return;
        }
        let written = unsafe {
            sys::storage_file_write(self.file, self.buf.as_ptr() as *const core::ffi::c_void, self.pos)
        };
        if written != self.pos {
            self.failed = true;
        } else {
            self.total_written += written;
        }
        self.pos = 0;
    }

    fn push_bytes(&mut self, bytes: &[u8]) {
        for &b in bytes {
            if self.pos >= self.buf.len() {
                self.flush();
            }
            self.buf[self.pos] = b;
            self.pos += 1;
        }
    }

    fn push_str(&mut self, s: &str) {
        self.push_bytes(s.as_bytes());
    }

    fn push_u16(&mut self, n: u16) {
        let mut tmp = [0u8; 6];
        let mut i = 0;
        let mut n = n;
        if n == 0 {
            tmp[i] = b'0';
            i = 1;
        } else {
            while n > 0 {
                tmp[i] = b'0' + (n % 10) as u8;
                i += 1;
                n /= 10;
            }
        }
        for j in (0..i).rev() {
            if self.pos >= self.buf.len() {
                self.flush();
            }
            self.buf[self.pos] = tmp[j];
            self.pos += 1;
        }
    }

    fn push_escaped(&mut self, s: &str) {
        for c in s.chars() {
            let bytes = match c {
                '"' => b"\\\"",
                '\\' => b"\\\\",
                '\n' => b"\\n",
                _ => {
                    let mut b = [0u8; 4];
                    let len = c.encode_utf8(&mut b).len();
                    self.push_bytes(&b[..len]);
                    continue;
                }
            };
            self.push_bytes(bytes);
        }
    }

    fn finish(&mut self) -> usize {
        self.flush();
        self.total_written
    }

    fn ok(&self) -> bool {
        !self.failed
    }
}

/// Write collection entries to JSON using streaming writer (no large heap alloc).
pub fn save_collection(entries: &[CollectionEntry]) -> bool {
    let mut path_buf = [0u8; 128];
    let path_c = match path_to_cstr(COLLECTION_PATH, &mut path_buf) {
        Some(p) => p,
        None => return false,
    };

    unsafe {
        let storage = sys::furi_record_open(c"storage".as_ptr() as *const u8);
        if storage.is_null() {
            return false;
        }

        let file = sys::storage_file_alloc(storage as *mut sys::Storage);
        if file.is_null() {
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return false;
        }

        let opened = sys::storage_file_open(file, path_c, sys::FSAM_WRITE, sys::FSOM_OPEN_ALWAYS);
        if !opened {
            sys::storage_file_close(file);
            sys::storage_file_free(file);
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return false;
        }

        sys::storage_file_truncate(file);

        let mut w = JsonWriter::new(file);

        w.push_str("{\"version\":\"kindled-flipper-v2\",\"passages\":[");
        for (i, entry) in entries.iter().enumerate() {
            if i > 0 {
                w.push_str(",");
            }
            w.push_str("{\"scripture_ref\":\"");
            w.push_escaped(&entry.scripture_ref);
            w.push_str("\",\"scripture_display_ref\":\"");
            w.push_escaped(&entry.scripture_display_ref);
            w.push_str("\",\"scripture_translation\":\"");
            w.push_escaped(&entry.scripture_translation);
            w.push_str("\",\"book_index\":");
            w.push_u16(entry.book_index as u16);
            w.push_str(",\"chapter\":");
            w.push_u16(entry.chapter);
            w.push_str(",\"start_verse\":");
            w.push_u16(entry.start_verse);
            w.push_str(",\"end_verse\":");
            w.push_u16(entry.end_verse);
            w.push_str(",\"captured_at\":\"");
            w.push_escaped(&entry.captured_at);
            w.push_str("\",\"note\":\"");
            w.push_escaped(&entry.note);
            w.push_str("\"}");
        }
        w.push_str("]}");

        let total = w.finish();
        let ok = w.ok() && total > 0;

        sys::storage_file_close(file);
        sys::storage_file_free(file);
        sys::furi_record_close(c"storage".as_ptr() as *const u8);

        ok
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
        if storage.is_null() {
            return Vec::new();
        }

        let file = sys::storage_file_alloc(storage as *mut sys::Storage);
        if file.is_null() {
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return Vec::new();
        }

        let opened = sys::storage_file_open(file, path_c, sys::FSAM_READ, sys::FSOM_OPEN_EXISTING);
        if !opened {
            sys::storage_file_close(file);
            sys::storage_file_free(file);
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return Vec::new();
        }

        // Read collection.json in small chunks to avoid large heap allocations.
        const CHUNK: usize = 1024;
        let mut buf: Vec<u8> = Vec::new();
        let mut chunk = [0u8; CHUNK];
        let mut total_read: usize = 0;
        loop {
            let n = sys::storage_file_read(
                file,
                chunk.as_mut_ptr() as *mut core::ffi::c_void,
                CHUNK,
            );
            if n == 0 || total_read + n > MAX_FILE_SIZE {
                break;
            }
            buf.extend_from_slice(&chunk[..n]);
            total_read += n;
        }
        sys::storage_file_close(file);
        sys::storage_file_free(file);
        sys::furi_record_close(c"storage".as_ptr() as *const u8);

        if buf.is_empty() {
            return Vec::new();
        }
        parse_collection_json(&buf)
    }
}

/// Parse collection JSON — minimal scanner for the Kindled schema (v2 metadata-only).
fn parse_collection_json(data: &[u8]) -> Vec<CollectionEntry> {
    let mut entries = Vec::new();
    let mut i = 0;
    let len = data.len();

    while i < len {
        if let Some(ref_start) = find_key_value(data, i, b"scripture_ref") {
            let ref_val = ref_start;
            i = ref_val.end;

            let display_ref = find_key_value(data, i, b"scripture_display_ref")
                .map(|r| r.to_string(data))
                .unwrap_or_default();
            let translation = find_key_value(data, i, b"scripture_translation")
                .map(|r| r.to_string(data))
                .unwrap_or_default();

            let book_index = find_key_value(data, i, b"book_index")
                .map(|r| parse_u16_from_bytes(&data[r.start..r.end]) as usize)
                .unwrap_or(0);
            let chapter = find_key_value(data, i, b"chapter")
                .map(|r| parse_u16_from_bytes(&data[r.start..r.end]))
                .unwrap_or(1);
            let start_verse = find_key_value(data, i, b"start_verse")
                .map(|r| parse_u16_from_bytes(&data[r.start..r.end]))
                .unwrap_or(0);
            let end_verse = find_key_value(data, i, b"end_verse")
                .map(|r| parse_u16_from_bytes(&data[r.start..r.end]))
                .unwrap_or(0);

            let captured_at = find_key_value(data, i, b"captured_at")
                .map(|r| r.to_string(data))
                .unwrap_or_default();
            let note = find_key_value(data, i, b"note")
                .map(|r| r.to_string(data))
                .unwrap_or_default();

            entries.push(CollectionEntry {
                scripture_ref: ref_val.to_string(data),
                scripture_display_ref: display_ref,
                scripture_translation: translation,
                book_index,
                chapter,
                start_verse,
                end_verse,
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
    if needle.is_empty() || start >= data.len() {
        return None;
    }
    data[start..]
        .windows(needle.len())
        .position(|w| w == needle)
        .map(|p| start + p)
}

fn find_key_value(data: &[u8], start: usize, key: &[u8]) -> Option<ByteRange> {
    let key_quoted_len = key.len() + 2; // "key"
    let search_start = start.saturating_sub(1);
    let mut i = search_start;
    while i + key_quoted_len + 2 < data.len() {
        if data[i] == b'"'
            && &data[i + 1..i + 1 + key.len()] == key
            && data[i + 1 + key.len()] == b'"'
        {
            // Skip past key and colon
            i += key_quoted_len + 1;
            while i < data.len() && (data[i] == b':' || data[i] == b' ' || data[i] == b'\t') {
                i += 1;
            }
            if i >= data.len() {
                return None;
            }
            // Extract value
            if data[i] == b'"' {
                i += 1;
                let val_start = i;
                while i < data.len() && data[i] != b'"' {
                    i += 1;
                }
                return Some(ByteRange {
                    start: val_start,
                    end: i,
                });
            } else {
                // Numeric value
                let val_start = i;
                while i < data.len() && data[i].is_ascii_digit() {
                    i += 1;
                }
                return Some(ByteRange {
                    start: val_start,
                    end: i,
                });
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

fn escape_json_str(out: &mut String, s: &str) {
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            _ => out.push(c),
        }
    }
}

/// Load verses for a CollectionEntry from the SD card, filtered to the saved range.
fn load_verses_for_entry(entry: &CollectionEntry) -> Vec<Verse> {
    let osis_lower = crate::books::OSIS_BOOK_CODES[entry.book_index].to_lowercase();
    if let Some(all_verses) = crate::bsb_loader::load_chapter(&osis_lower, entry.chapter) {
        all_verses
            .into_iter()
            .filter(|v| v.number >= entry.start_verse && v.number <= entry.end_verse)
            .collect()
    } else {
        Vec::new()
    }
}

/// Build Kindled-format JSON string in memory (for NFC export).
/// Reloads verse text from SD card for each entry.  
/// WARNING: can OOM on large collections; caller should check size.
pub fn build_kindled_json(entries: &[CollectionEntry]) -> String {
    let mut json = String::with_capacity(8192);
    json.push_str("{\"format\":\"kindled\",\"version\":1,\"exported_at\":\"2026-01-01T00:00:00Z\",\"schema_version\":1,\"counts\":{\"blocks\":");
    json.push_str(&u16_to_string(entries.len() as u16));
    json.push_str(",\"entities\":0,\"links\":0,\"reflections\":0,\"life_stages\":0},\"data\":{\"blocks\":[");

    for (i, entry) in entries.iter().enumerate() {
        if i > 0 {
            json.push(',');
        }
        let verses = load_verses_for_entry(entry);
        json.push_str("{\"id\":\"block-");
        json.push_str(&u16_to_string(i as u16));
        json.push_str("\",\"type\":\"scripture\",\"content\":\"");
        escape_json_str(&mut json, &entry.scripture_display_ref);
        json.push_str("\",\"scripture_ref\":\"");
        escape_json_str(&mut json, &entry.scripture_ref);
        json.push_str("\",\"scripture_display_ref\":\"");
        escape_json_str(&mut json, &entry.scripture_display_ref);
        json.push_str("\",\"scripture_translation\":\"");
        escape_json_str(&mut json, &entry.scripture_translation);
        json.push_str("\",\"scripture_verses\":[");
        for (j, verse) in verses.iter().enumerate() {
            if j > 0 {
                json.push(',');
            }
            json.push_str("{\"number\":");
            json.push_str(&u16_to_string(verse.number));
            json.push_str(",\"text\":\"");
            escape_json_str(&mut json, &verse.text);
            json.push('"');
            json.push('}');
        }
        json.push_str("],\"source\":\"manual\",\"captured_at\":\"");
        escape_json_str(&mut json, &entry.captured_at);
        json.push_str("\",\"modified_at\":\"");
        escape_json_str(&mut json, &entry.captured_at);
        json.push_str("\",\"tags\":[]}");
    }

    json.push_str("],\"entities\":[],\"links\":[],\"reflections\":[],\"life_stages\":[]}}");
    json
}
