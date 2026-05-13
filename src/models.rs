/// Core data types matching Kindled web-app schema
use alloc::string::String;
use alloc::vec::Vec;

#[derive(Clone)]
pub struct Verse {
    pub number: u16,
    pub text: String,
}

pub struct Passage {
    pub book_index: usize,
    pub chapter: u16,
    pub start_verse: u16,
    pub end_verse: u16,
    pub verses: Vec<Verse>,
}

pub struct CollectionEntry {
    pub scripture_ref: String,
    pub scripture_display_ref: String,
    pub scripture_translation: String,
    pub verses: Vec<Verse>,
    pub captured_at: String,
    pub note: String,
}

fn u16_to_string(n: u16) -> String {
    let mut buf = [0u8; 6];
    let mut i = 0;
    let mut n = n;
    if n == 0 {
        return String::from("0");
    }
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

impl Passage {
    pub fn display_ref(&self) -> String {
        use crate::books;
        let mut s = String::with_capacity(64);
        s.push_str(books::OSIS_BOOK_NAMES[self.book_index]);
        s.push(' ');
        s.push_str(&u16_to_string(self.chapter));
        if self.start_verse > 0 {
            s.push(':');
            s.push_str(&u16_to_string(self.start_verse));
            if self.end_verse > self.start_verse {
                s.push('-');
                s.push_str(&u16_to_string(self.end_verse));
            }
        }
        s
    }

    pub fn canonical_ref(&self) -> String {
        use crate::books;
        let mut s = String::with_capacity(64);
        let code = books::OSIS_BOOK_CODES[self.book_index];
        s.push_str(code);
        s.push('.');
        s.push_str(&u16_to_string(self.chapter));
        if self.start_verse > 0 {
            s.push('.');
            s.push_str(&u16_to_string(self.start_verse));
            if self.end_verse > self.start_verse {
                s.push('-');
                s.push_str(code);
                s.push('.');
                s.push_str(&u16_to_string(self.chapter));
                s.push('.');
                s.push_str(&u16_to_string(self.end_verse));
            }
        }
        s
    }
}
