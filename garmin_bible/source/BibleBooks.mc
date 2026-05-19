import Toybox.Lang;

module BibleBooks {
    const BOOK_COUNT = 66;

    // Canonical book names (BSB display names)
    const BOOK_NAMES = [
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
        "Revelation"
    ];

    // OSIS codes (lowercased for URL building)
    const OSIS_CODES = [
        "gen", "exo", "lev", "num", "deu",
        "jos", "jdg", "rut", "1sa", "2sa",
        "1ki", "2ki", "1ch", "2ch", "ezr",
        "neh", "est", "job", "psa", "pro",
        "ecc", "sng", "isa", "jer", "lam",
        "ezk", "dan", "hos", "jol", "amo",
        "oba", "jon", "mic", "nam", "hab",
        "zep", "hag", "zec", "mal", "mat",
        "mrk", "luk", "jhn", "act", "rom",
        "1co", "2co", "gal", "eph", "php",
        "col", "1th", "2th", "1ti", "2ti",
        "tit", "phm", "heb", "jas", "1pe",
        "2pe", "1jn", "2jn", "3jn", "jud",
        "rev"
    ];

    // Chapter counts per book
    const CHAPTER_COUNTS = [
        50, 40, 27, 36, 34,
        24, 21, 4, 31, 24,
        22, 25, 29, 36, 10,
        13, 10, 42, 150, 31,
        12, 8, 66, 52, 5,
        48, 12, 14, 3, 9,
        1, 4, 7, 3, 3,
        3, 2, 14, 4, 28,
        16, 24, 21, 28, 16,
        16, 13, 6, 6, 4,
        4, 5, 3, 6, 4,
        3, 1, 13, 5, 5,
        3, 5, 1, 1, 1,
        22
    ];

    // Filter initials: All + unique first characters (alphabetic + numeric)
    // Books: Genesis(G), Exodus(E), Leviticus(L), Numbers(N), Deuteronomy(D),
    // Joshua(J), Judges(J), Ruth(R), 1 Samuel(1), 2 Samuel(2),
    // 1 Kings(1), 2 Kings(2), 1 Chronicles(1), 2 Chronicles(2), Ezra(E),
    // Nehemiah(N), Esther(E), Job(J), Psalms(P), Proverbs(P),
    // Ecclesiastes(E), Song of Solomon(S), Isaiah(I), Jeremiah(J), Lamentations(L),
    // Ezekiel(E), Daniel(D), Hosea(H), Joel(J), Amos(A),
    // Obadiah(O), Jonah(J), Micah(M), Nahum(N), Habakkuk(H),
    // Zephaniah(Z), Haggai(H), Zechariah(Z), Malachi(M), Matthew(M),
    // Mark(M), Luke(L), John(J), Acts(A), Romans(R),
    // 1 Corinthians(1), 2 Corinthians(2), Galatians(G), Ephesians(E), Philippians(P),
    // Colossians(C), 1 Thessalonians(1), 2 Thessalonians(2), 1 Timothy(1), 2 Timothy(2),
    // Titus(T), Philemon(P), Hebrews(H), James(J), 1 Peter(1),
    // 2 Peter(2), 1 John(1), 2 John(2), 3 John(3), Jude(J),
    // Revelation(R)
    // Unique first characters = 21: A, C, D, E, G, H, I, J, K, L, M, N, O, P, R, S, T, Z, 1, 2, 3
    // Total filter options = All + 21 = 22
    const FILTER_OPTIONS = [
        "All", "A", "C", "D", "E", "G", "H", "I", "J", "K",
        "L", "M", "N", "O", "P", "R", "S", "T", "Z", "1",
        "2", "3"
    ];
    const FILTER_COUNT = 22;

    function getBookName(index as Number) as String {
        if (index < 0 || index >= BOOK_COUNT) {
            return "";
        }
        return BOOK_NAMES[index];
    }

    function getOsisCode(index as Number) as String {
        if (index < 0 || index >= BOOK_COUNT) {
            return "";
        }
        return OSIS_CODES[index];
    }

    function getChapterCount(index as Number) as Number {
        if (index < 0 || index >= BOOK_COUNT) {
            return 0;
        }
        return CHAPTER_COUNTS[index];
    }

    function getVerseCount(bookIndex as Number, chapter as Number) as Number {
        if (bookIndex < 0 || bookIndex >= BOOK_COUNT || chapter < 1) {
            return 0;
        }
        var maxCh = getChapterCount(bookIndex);
        if (chapter > maxCh) {
            return 0;
        }
        // Verse counts for Genesis 1-10
        if (bookIndex == 0) {
            var genesisVerses = [31, 25, 24, 26, 32, 22, 24, 22, 29, 32] as Array<Number>;
            if (chapter <= genesisVerses.size()) {
                return genesisVerses[chapter - 1];
            }
            return 0;
        }
        // Verse counts for representative Psalms
        if (bookIndex == 18) {
            if (chapter == 119) {
                return 176;
            }
            if (chapter == 23) {
                return 6;
            }
            if (chapter == 1) {
                return 6;
            }
            if (chapter == 2) {
                return 12;
            }
            if (chapter == 3) {
                return 8;
            }
            if (chapter == 117) {
                return 2;
            }
            if (chapter == 150) {
                return 6;
            }
            return 0;
        }
        // Verse counts for all John chapters
        if (bookIndex == 42) {
            var johnVerses = [51, 25, 36, 54, 47, 71, 53, 59, 41, 42, 57, 50, 38, 31, 27, 33, 26, 40, 42, 31, 25] as Array<Number>;
            if (chapter <= johnVerses.size()) {
                return johnVerses[chapter - 1];
            }
            return 0;
        }
        return 0;
    }

    function getFilterOption(index as Number) as String {
        if (index < 0 || index >= FILTER_COUNT) {
            return "";
        }
        return FILTER_OPTIONS[index];
    }

    function getFilteredBooks(filter as String) as Array<Number> {
        var result = [] as Array<Number>;
        var allFilter = "";
        if (filter.length() == 0 || filter == allFilter || filter == "All") {
            for (var i = 0; i < BOOK_COUNT; i++) {
                result.add(i);
            }
            return result;
        }
        var initial = filter.substring(0, 1);
        for (var i = 0; i < BOOK_COUNT; i++) {
            var name = getBookName(i);
            if (name.length() > 0 && name.substring(0, 1) == initial) {
                result.add(i);
            }
        }
        return result;
    }
}
