/// Static Bible book metadata — ported from selah-tools/packages/grab-bcv/src/books.ts

pub const OSIS_BOOK_CODES: [&str; 66] = [
    "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA",
    "1KI", "2KI", "1CH", "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO",
    "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO",
    "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL", "MAT",
    "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP",
    "COL", "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE",
    "2PE", "1JN", "2JN", "3JN", "JUD", "REV",
];

pub const OSIS_BOOK_NAMES: [&str; 66] = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
    "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
    "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra",
    "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
    "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations",
    "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
    "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
    "Zephaniah", "Haggai", "Zechariah", "Malachi", "Matthew",
    "Mark", "Luke", "John", "Acts", "Romans",
    "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians", "Philippians",
    "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy",
    "Titus", "Philemon", "Hebrews", "James", "1 Peter",
    "2 Peter", "1 John", "2 John", "3 John", "Jude",
    "Revelation",
];

pub const BOOK_CHAPTER_COUNTS: [u16; 66] = [
    50, 40, 27, 36, 34, 24, 21, 4, 31, 24,
    22, 25, 29, 36, 10, 13, 10, 42, 150, 31,
    12, 8, 66, 52, 5, 48, 12, 14, 3, 9,
    1, 4, 7, 3, 3, 3, 2, 14, 4, 28,
    16, 24, 21, 28, 16, 16, 13, 6, 6, 4,
    4, 5, 3, 6, 4, 3, 1, 13, 5, 5,
    3, 5, 1, 1, 1, 22,
];

/// Max verses per chapter for each book — used for verse-range selection validation.
/// Only storing a subset for brevity; the fetch script fills the rest.
pub fn max_verse_for_chapter(book_index: usize, chapter: u16) -> u16 {
    match book_index {
        // Genesis
        0 => match chapter {
            1 => 31, 2 => 25, 3 => 24, 4 => 26, 5 => 32,
            6 => 22, 7 => 24, 8 => 22, 9 => 29, 10 => 32,
            _ => 30,
        },
        // Psalms
        18 => match chapter {
            1 => 6, 2 => 12, 3 => 8, 4 => 8, 5 => 12,
            6 => 10, 7 => 17, 8 => 9, 9 => 20, 10 => 18,
            11 => 7, 12 => 8, 13 => 6, 14 => 7, 15 => 5,
            16 => 11, 17 => 15, 18 => 50, 19 => 14, 20 => 9,
            21 => 13, 22 => 31, 23 => 6, 24 => 10, 25 => 22,
            26 => 12, 27 => 14, 28 => 9, 29 => 11, 30 => 12,
            31 => 24, 32 => 11, 33 => 22, 34 => 22, 35 => 28,
            36 => 12, 37 => 40, 38 => 22, 39 => 13, 40 => 17,
            41 => 13, 42 => 11, 43 => 5, 44 => 26, 45 => 17,
            46 => 11, 47 => 9, 48 => 14, 49 => 20, 50 => 23,
            51 => 19, 52 => 9, 53 => 6, 54 => 7, 55 => 23,
            56 => 13, 57 => 11, 58 => 11, 59 => 17, 60 => 12,
            61 => 8, 62 => 12, 63 => 11, 64 => 10, 65 => 13,
            66 => 20, 67 => 7, 68 => 35, 69 => 36, 70 => 5,
            71 => 24, 72 => 20, 73 => 28, 74 => 23, 75 => 10,
            76 => 12, 77 => 20, 78 => 72, 79 => 13, 80 => 19,
            81 => 16, 82 => 8, 83 => 18, 84 => 12, 85 => 13,
            86 => 17, 87 => 7, 88 => 18, 89 => 52, 90 => 17,
            91 => 16, 92 => 15, 93 => 5, 94 => 23, 95 => 11,
            96 => 13, 97 => 12, 98 => 9, 99 => 9, 100 => 5,
            101 => 8, 102 => 28, 103 => 22, 104 => 35, 105 => 45,
            106 => 48, 107 => 43, 108 => 13, 109 => 31, 110 => 7,
            111 => 10, 112 => 10, 113 => 9, 114 => 8, 115 => 18,
            116 => 19, 117 => 2, 118 => 29, 119 => 176, 120 => 7,
            121 => 8, 122 => 9, 123 => 4, 124 => 8, 125 => 5,
            126 => 6, 127 => 5, 128 => 6, 129 => 8, 130 => 8,
            131 => 3, 132 => 18, 133 => 3, 134 => 3, 135 => 21,
            136 => 26, 137 => 9, 138 => 8, 139 => 24, 140 => 13,
            141 => 10, 142 => 7, 143 => 12, 144 => 15, 145 => 21,
            146 => 10, 147 => 20, 148 => 14, 149 => 9, 150 => 6,
            _ => 10,
        },
        // John
        42 => match chapter {
            1 => 51, 2 => 25, 3 => 36, 4 => 54, 5 => 47,
            6 => 71, 7 => 53, 8 => 59, 9 => 41, 10 => 42,
            11 => 57, 12 => 50, 13 => 38, 14 => 31, 15 => 27,
            16 => 33, 17 => 26, 18 => 40, 19 => 42, 20 => 31,
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
