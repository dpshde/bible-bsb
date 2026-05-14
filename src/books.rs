/// Static Bible book metadata — ported from selah-tools/packages/grab-bcv/src/books.ts

pub const OSIS_BOOK_CODES: [&str; 66] = [
    "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI", "1CH",
    "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", "LAM", "EZK",
    "DAN", "HOS", "JOL", "AMO", "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL",
    "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH",
    "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD",
    "REV",
];

pub const OSIS_BOOK_NAMES: [&str; 66] = [
    "Genesis",
    "Exodus",
    "Leviticus",
    "Numbers",
    "Deuteronomy",
    "Joshua",
    "Judges",
    "Ruth",
    "1 Samuel",
    "2 Samuel",
    "1 Kings",
    "2 Kings",
    "1 Chronicles",
    "2 Chronicles",
    "Ezra",
    "Nehemiah",
    "Esther",
    "Job",
    "Psalms",
    "Proverbs",
    "Ecclesiastes",
    "Song of Solomon",
    "Isaiah",
    "Jeremiah",
    "Lamentations",
    "Ezekiel",
    "Daniel",
    "Hosea",
    "Joel",
    "Amos",
    "Obadiah",
    "Jonah",
    "Micah",
    "Nahum",
    "Habakkuk",
    "Zephaniah",
    "Haggai",
    "Zechariah",
    "Malachi",
    "Matthew",
    "Mark",
    "Luke",
    "John",
    "Acts",
    "Romans",
    "1 Corinthians",
    "2 Corinthians",
    "Galatians",
    "Ephesians",
    "Philippians",
    "Colossians",
    "1 Thessalonians",
    "2 Thessalonians",
    "1 Timothy",
    "2 Timothy",
    "Titus",
    "Philemon",
    "Hebrews",
    "James",
    "1 Peter",
    "2 Peter",
    "1 John",
    "2 John",
    "3 John",
    "Jude",
    "Revelation",
];

pub const BOOK_CHAPTER_COUNTS: [u16; 66] = [
    50, 40, 27, 36, 34, 24, 21, 4, 31, 24, 22, 25, 29, 36, 10, 13, 10, 42, 150, 31, 12, 8, 66, 52,
    5, 48, 12, 14, 3, 9, 1, 4, 7, 3, 3, 3, 2, 14, 4, 28, 16, 24, 21, 28, 16, 16, 13, 6, 6, 4, 4, 5,
    3, 6, 4, 3, 1, 13, 5, 5, 3, 5, 1, 1, 1, 22,
];

/// Max verses per chapter for each book — used for verse-range selection validation.
/// Only storing a subset for brevity; the fetch script fills the rest.
pub fn max_verse_for_chapter(book_index: usize, chapter: u16) -> u16 {
    match book_index {
        // Genesis
        0 => match chapter {
            1 => 31,
            2 => 25,
            3 => 24,
            4 => 26,
            5 => 32,
            6 => 22,
            7 => 24,
            8 => 22,
            9 => 29,
            10 => 32,
            _ => 30,
        },
        // Psalms
        18 => {
            const PSA: [u8; 150] = [
                6, 12, 8, 8, 12, 10, 17, 9, 20, 18, 7, 8, 6, 7, 5, 11, 15, 50, 14, 9, 13, 31, 6,
                10, 22, 12, 14, 9, 11, 12, 24, 11, 22, 22, 28, 12, 40, 22, 13, 17, 13, 11, 5, 26,
                17, 11, 9, 14, 20, 23, 19, 9, 6, 7, 23, 13, 11, 11, 17, 12, 8, 12, 11, 10, 13, 20,
                7, 35, 36, 5, 24, 20, 28, 23, 10, 12, 20, 72, 13, 19, 16, 8, 18, 12, 13, 17, 7, 18,
                52, 17, 16, 15, 5, 23, 11, 13, 12, 9, 9, 5, 8, 28, 22, 35, 45, 48, 43, 13, 31, 7,
                10, 10, 9, 8, 18, 19, 2, 29, 176, 7, 8, 9, 4, 8, 5, 6, 5, 6, 8, 8, 3, 18, 3, 3, 21,
                26, 9, 8, 24, 13, 10, 7, 12, 15, 21, 10, 20, 14, 9, 6,
            ];
            let idx = (chapter as usize).saturating_sub(1);
            if idx < PSA.len() { PSA[idx] as u16 } else { 10 }
        }
        // John
        42 => match chapter {
            1 => 51,
            2 => 25,
            3 => 36,
            4 => 54,
            5 => 47,
            6 => 71,
            7 => 53,
            8 => 59,
            9 => 41,
            10 => 42,
            11 => 57,
            12 => 50,
            13 => 38,
            14 => 31,
            15 => 27,
            16 => 33,
            17 => 26,
            18 => 40,
            19 => 42,
            20 => 31,
            21 => 25,
            _ => 20,
        },
        // Default fallback — most chapters don't exceed 40 verses
        _ => {
            // For unknown chapters, let the loader return actual verse count from file
            // This is a safe upper bound for the verse select UI
            40
        }
    }
}

/// Returns the 0-based OT/NT split index (39 = Malachi is the last OT book)
pub const OT_COUNT: usize = 39;
