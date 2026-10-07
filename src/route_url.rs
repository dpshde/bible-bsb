/// Build canonical route.bible URLs from passage data.
/// Ported from selah-tools/packages/route-bible-core/src/links.ts
use alloc::string::String;

const ROUTE_BASE: &str = "https://route.bible";
const DEFAULT_TRANSLATION: &str = "BSB";
const SOURCE_TAG: &str = "bible_bsb";

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

/// Build a canonical route.bible URL from passage components.
/// Example: `https://route.bible/gen.1.1-3?v=BSB&src=bible_bsb`
pub fn build_url(book_code: &str, chapter: u16, start_verse: u16, end_verse: u16) -> String {
    let code_lower = book_code.to_lowercase();
    let mut path = String::with_capacity(32);
    path.push('/');
    path.push_str(&code_lower);
    path.push('.');
    path.push_str(&u16_to_string(chapter));
    if start_verse > 0 {
        path.push('.');
        path.push_str(&u16_to_string(start_verse));
        if end_verse > start_verse {
            path.push('-');
            path.push_str(&code_lower);
            path.push('.');
            path.push_str(&u16_to_string(chapter));
            path.push('.');
            path.push_str(&u16_to_string(end_verse));
        }
    }

    let mut url = String::with_capacity(128);
    url.push_str(ROUTE_BASE);
    url.push_str(&path);
    url.push_str("?v=");
    url.push_str(DEFAULT_TRANSLATION);
    url.push_str("&src=");
    url.push_str(SOURCE_TAG);
    url
}
