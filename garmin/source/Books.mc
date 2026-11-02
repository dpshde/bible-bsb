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

    const CHAPTER_COUNTS = [
        50, 40, 27, 36, 34, 24, 21, 4, 31, 24, 22, 25, 29, 36, 10, 13, 10, 42, 150, 31, 12, 8,
        66, 52, 5, 48, 12, 14, 3, 9, 1, 4, 7, 3, 3, 3, 2, 14, 4, 28, 16, 24, 21, 28,
        16, 16, 13, 6, 6, 4, 4, 5, 3, 6, 4, 3, 1, 13, 5, 5, 3, 5, 1, 1, 1, 22
    ];

    //! Spike: books that have bundled JSON (see ContentLoader).
    const SPIKE_BOOK_INDEXES = [38, 39, 42]; // Malachi, Matthew, John

    function name(bookIndex as Lang.Number) as Lang.String {
        if (bookIndex < 0 || bookIndex >= BOOK_COUNT) {
            return "?";
        }
        return NAMES[bookIndex];
    }

    function chapterCount(bookIndex as Lang.Number) as Lang.Number {
        if (bookIndex < 0 || bookIndex >= BOOK_COUNT) {
            return 0;
        }
        return CHAPTER_COUNTS[bookIndex];
    }

    function shortName(bookIndex as Lang.Number) as Lang.String {
        // POKE: try OSIS codes or smarter abbreviations per display width.
        var n = name(bookIndex);
        if (n.length() <= 6) {
            return n;
        }
        return n.substring(0, 5);
    }
}
