using Toybox.Lang;

//! Canon metadata for the spike (subset + full chapter counts for nav math).
module Books {
    const BOOK_COUNT = 66;
    const OT_COUNT = 39; // indices 0..38 OT, 39..65 NT

    //! Display names (full canon — spike UI may only list books with content).
    const NAMES = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
        "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra",
        "Nehemiah", "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon",
        "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
        "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah",
        "Malachi", "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians",
        "2 Corinthians", "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians",
        "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James",
        "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation"
    ];

    //! OSIS-style short codes for the top-arc meta line (e.g. JHN 3:16).
    const OSIS = [
        "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT",
        "1SA", "2SA", "1KI", "2KI", "1CH", "2CH", "EZR",
        "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG",
        "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO",
        "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC",
        "MAL", "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO",
        "2CO", "GAL", "EPH", "PHP", "COL", "1TH",
        "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS",
        "1PE", "2PE", "1JN", "2JN", "3JN", "JUD", "REV"
    ];

    const CHAPTER_COUNTS = [
        50, 40, 27, 36, 34, 24, 21, 4, 31, 24, 22, 25, 29, 36, 10, 13, 10, 42, 150, 31, 12, 8,
        66, 52, 5, 48, 12, 14, 3, 9, 1, 4, 7, 3, 3, 3, 2, 14, 4, 28, 16, 24, 21, 28,
        16, 16, 13, 6, 6, 4, 4, 5, 3, 6, 4, 3, 1, 13, 5, 5, 3, 5, 1, 1, 1, 22
    ];

    //! Spike: books that have bundled JSON (see ContentLoader).
    const SPIKE_BOOK_INDEXES = [38, 39, 42]; // Malachi, Matthew, John

    //! Last-resort abbreviations (Dylan 4:39 PM: only when a full name truly cannot fit
    //! the circle at that row's y; callers log every use). POKE: BOOK_ABBREV
    const ABBREV = {
        "1 Thessalonians" => "1 Thess.", "2 Thessalonians" => "2 Thess.",
        "Song of Solomon" => "Song", "1 Chronicles" => "1 Chron.", "2 Chronicles" => "2 Chron.",
        "Lamentations" => "Lam.", "Deuteronomy" => "Deut.", "Ecclesiastes" => "Eccl.",
        "1 Corinthians" => "1 Cor.", "2 Corinthians" => "2 Cor.", "Philippians" => "Phil.",
        "Colossians" => "Col.", "Zephaniah" => "Zeph.", "Zechariah" => "Zech.",
        "Revelation" => "Rev.", "Leviticus" => "Lev.", "Galatians" => "Gal.", "Ephesians" => "Eph."
    };

    function abbrevLabel(label as Lang.String) as Lang.String {
        var a = ABBREV[label];
        return a != null ? a as Lang.String : label;
    }

    function name(bookIndex as Lang.Number) as Lang.String {
        if (bookIndex < 0 || bookIndex >= BOOK_COUNT) {
            return "?";
        }
        return NAMES[bookIndex];
    }

    function osis(bookIndex as Lang.Number) as Lang.String {
        if (bookIndex < 0 || bookIndex >= BOOK_COUNT) {
            return "?";
        }
        return OSIS[bookIndex];
    }

    function chapterCount(bookIndex as Lang.Number) as Lang.Number {
        if (bookIndex < 0 || bookIndex >= BOOK_COUNT) {
            return 0;
        }
        return CHAPTER_COUNTS[bookIndex];
    }

    //! Short label for meta / tight chrome. Prefers OSIS; full name when it fits.
    function shortName(bookIndex as Lang.Number) as Lang.String {
        return osis(bookIndex);
    }

    //! "JHN 3:16" — OSIS + chapter:verse. Full name allowed by caller if width permits.
    function refLabel(bookIndex as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Lang.String {
        if (verse <= 0) {
            return osis(bookIndex) + " " + chapter;
        }
        return osis(bookIndex) + " " + chapter + ":" + verse;
    }
}
