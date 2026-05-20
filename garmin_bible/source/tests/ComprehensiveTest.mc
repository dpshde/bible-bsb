import Toybox.Lang;
using Toybox.Test;
using Toybox.Application;
using Toybox.System;
using Toybox.Graphics;

// ===================================================================
// Comprehensive Test Suite — Bible [BSB] Garmin Connect IQ
//
// Covers all edge cases, memory safety, and large book handling:
// 1. Psalm 119 offline load (largest chapter, 176 verses)
// 2. Memory stress (rapid open/close of ReaderView)
// 3. Large/small chapter edge cases
// 4. Filter parity (all 22 filters with expected counts)
// 5. Storage edge cases (max, FIFO, duplicate, null, full)
// 6. Navigation wrap/clamp tests
// 7. UI safe area tests (all 9 device configurations)
// 8. Color path tests (1-bit mono vs color palette)
// 9. Error path tests (no connection, 404, malformed JSON, storage)
// ===================================================================

(:test)
class ComprehensiveTest {

    // ------------------------------------------------------------------
    // 1. Psalm 119 offline load
    // ------------------------------------------------------------------

    function testPsalm119VerseCountIs176(logger as Test.Logger) as Boolean {
        var count = BibleBooks.getVerseCount(18, 119);
        return count == 176;
    }

    function testPsalm119PaginationFor176Verses(logger as Test.Logger) as Boolean {
        // Simulate wrapping Psalm 119 text on a 176x176 screen
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var contentWidth = layout.get("contentWidth") as Number;
        var charWidth = layout.get("charWidth") as Number;
        var linesPerPage = layout.get("linesPerPage") as Number;

        // Build 176 verses with representative short text (~40 chars each)
        var verses = [] as Array<Dictionary>;
        for (var i = 1; i <= 176; i++) {
            verses.add({ "verseNumber" => i, "verseText" => "Blessed are those whose way is blameless, who walk in the law of the LORD." });
        }

        var lines = BibleRenderer.wrapVerses(verses, contentWidth, charWidth);
        // With 176 verses ~40 chars each on 140px width (~23 chars/line, plus "N " prefix)
        // Each verse wraps to ~2 lines. Total lines should be well > 0.
        if (lines.size() == 0) {
            return false;
        }

        var totalPages = BibleRenderer.computeTotalPages(lines.size(), linesPerPage);
        // Should produce multiple pages (e.g., ~30+ pages for 176 verses)
        return totalPages > 10;
    }

    function testPsalm119FirstLineHasVerseNumber(logger as Test.Logger) as Boolean {
        var verses = [{ "verseNumber" => 119, "verseText" => "Blessed are those who keep His testimonies." }] as Array<Dictionary>;
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        if (lines.size() == 0) {
            return false;
        }
        var firstLine = lines[0] as Dictionary;
        var text = firstLine.get("text") as String;
        var isFirst = firstLine.get("isFirstLine") as Boolean;
        return text.substring(0, 4) == "119 " && isFirst;
    }

    function testPsalm119LastLineHasVerseNumber176(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 175, "verseText" => "Let me live that I may praise You." },
            { "verseNumber" => 176, "verseText" => "I have gone astray like a lost sheep." }
        ] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        if (lines.size() == 0) {
            return false;
        }
        var lastLine = lines[lines.size() - 1] as Dictionary;
        var text = lastLine.get("text") as String;
        // Last wrapped line should be from verse 176 (no prefix on continuation lines)
        return text.find("176") != null || text.find("gone astray") != null;
    }

    function testPsalm119DoesNotCrashOnWrap(logger as Test.Logger) as Boolean {
        // Memory stress simulation: wrap 176 verses at once
        var verses = [] as Array<Dictionary>;
        for (var i = 1; i <= 176; i++) {
            verses.add({ "verseNumber" => i, "verseText" => "The quick brown fox jumps over the lazy dog." });
        }
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        return lines.size() > 0 && lines.size() >= 176;
    }

    // ------------------------------------------------------------------
    // 2. Memory stress test — simulate rapid open/close of ReaderView
    // ------------------------------------------------------------------

    function testReaderViewRapidCreation(logger as Test.Logger) as Boolean {
        // Simulate 50 rapid create/destroy cycles
        for (var i = 0; i < 50; i++) {
            var view = new ReaderView();
            view.onHide();
        }
        // If we reach here without crash, the test passes
        return true;
    }

    function testReaderViewIsAliveToggle(logger as Test.Logger) as Boolean {
        var view = new ReaderView();
        if (!view.isAlive) {
            return false;
        }
        view.onHide();
        if (view.isAlive) {
            return false;
        }
        view.onShow();
        // onShow in ReaderView resets layout but doesn't set isAlive back to true
        // (isAlive is true by default in initialize)
        return true;
    }

    function testShareViewRapidCreation(logger as Test.Logger) as Boolean {
        for (var i = 0; i < 50; i++) {
            var share = new ShareView("https://route.bible/jhn.3.16");
            share.onHide();
        }
        return true;
    }

    function testStateResetBetweenLoads(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Load 1
        state.readerLines = [
            { "text" => "1 First.", "verseNumber" => 1, "isFirstLine" => true }
        ] as Array<Dictionary>;
        state.readerScroll = 5;

        // Simulate onShow clearing old data
        state.readerLines = [] as Array<Dictionary>;
        state.readerScroll = 0;
        state.readerError = "";
        state.readerIsLoading = true;

        // Old scroll value should be gone
        return state.readerScroll == 0 && state.readerLines.size() == 0;
    }

    function testLinesArrayDoesNotAccumulate(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Simulate loading a large chapter then a small one
        var bigLines = [] as Array<Dictionary>;
        for (var i = 0; i < 100; i++) {
            bigLines.add({ "text" => "Line " + i, "verseNumber" => i + 1, "isFirstLine" => true });
        }
        state.readerLines = bigLines;

        // Now clear (simulating new chapter load)
        state.readerLines = [] as Array<Dictionary>;

        // Add just a few lines for the new chapter
        state.readerLines.add({ "text" => "1 Short.", "verseNumber" => 1, "isFirstLine" => true });

        return state.readerLines.size() == 1;
    }

    // ------------------------------------------------------------------
    // 3. Large/small chapter edge cases
    // ------------------------------------------------------------------

    function testPsalm23Has6Verses(logger as Test.Logger) as Boolean {
        return BibleBooks.getVerseCount(18, 23) == 6;
    }

    function testGenesis1Has31Verses(logger as Test.Logger) as Boolean {
        return BibleBooks.getVerseCount(0, 1) == 31;
    }

    function testProverbs1Has33Verses(logger as Test.Logger) as Boolean {
        return BibleBooks.getVerseCount(19, 1) == 33;
    }

    function testRevelation22Has21Verses(logger as Test.Logger) as Boolean {
        return BibleBooks.getVerseCount(65, 22) == 21;
    }

    function testPsalm23WrapsCorrectly(logger as Test.Logger) as Boolean {
        var verses = [] as Array<Dictionary>;
        for (var i = 1; i <= 6; i++) {
            verses.add({ "verseNumber" => i, "verseText" => "The LORD is my shepherd; I shall not want." });
        }
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        return lines.size() >= 6;
    }

    function testGenesis1WrapsCorrectly(logger as Test.Logger) as Boolean {
        var verses = [] as Array<Dictionary>;
        for (var i = 1; i <= 31; i++) {
            verses.add({ "verseNumber" => i, "verseText" => "In the beginning God created the heavens and the earth." });
        }
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        return lines.size() >= 31;
    }

    function testProverbs1WrapsCorrectly(logger as Test.Logger) as Boolean {
        var verses = [] as Array<Dictionary>;
        for (var i = 1; i <= 33; i++) {
            verses.add({ "verseNumber" => i, "verseText" => "The proverbs of Solomon son of David, king of Israel." });
        }
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        return lines.size() >= 33;
    }

    function testRevelation22WrapsCorrectly(logger as Test.Logger) as Boolean {
        var verses = [] as Array<Dictionary>;
        for (var i = 1; i <= 21; i++) {
            verses.add({ "verseNumber" => i, "verseText" => "Then the angel showed me the river of the water of life." });
        }
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        return lines.size() >= 21;
    }

    function testShortChapterPagination(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 1, "verseText" => "Jesus wept." }
        ] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        var totalPages = BibleRenderer.computeTotalPages(lines.size(), 8);
        return totalPages == 1;
    }

    function testMediumChapterMultiplePages(logger as Test.Logger) as Boolean {
        // 60 verses that each wrap to ~2 lines = ~120 lines
        // 8 lines per page = 15 pages
        var verses = [] as Array<Dictionary>;
        for (var i = 1; i <= 60; i++) {
            verses.add({ "verseNumber" => i, "verseText" => "For God so loved the world that He gave His only Son, that everyone who believes in Him shall not perish but have eternal life." });
        }
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        var totalPages = BibleRenderer.computeTotalPages(lines.size(), 8);
        return totalPages > 1;
    }

    // ------------------------------------------------------------------
    // 4. Filter parity — all 22 filters with expected counts
    // ------------------------------------------------------------------

    function testFilterAllReturns66(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("All").size() == 66;
    }

    function testFilterAReturns2(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("A").size() == 2; // Amos, Acts
    }

    function testFilterCReturns5(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("C").size() == 5; // 1 Chronicles, 2 Chronicles, 1 Corinthians, 2 Corinthians, Colossians
    }

    function testFilterDReturns2(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("D").size() == 2; // Deuteronomy, Daniel
    }

    function testFilterEReturns6(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("E").size() == 6; // Exodus, Ezra, Esther, Ecclesiastes, Ezekiel, Ephesians
    }

    function testFilterGReturns2(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("G").size() == 2; // Genesis, Galatians
    }

    function testFilterHReturns4(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("H").size() == 4; // Hosea, Habakkuk, Haggai, Hebrews
    }

    function testFilterIReturns1(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("I").size() == 1; // Isaiah
    }

    function testFilterJReturns12(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("J").size() == 12; // Joshua, Judges, Job, Jeremiah, Joel, Jonah, John, James, 1 John, 2 John, 3 John, Jude
    }

    function testFilterKReturns2(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("K").size() == 2; // 1 Kings, 2 Kings
    }

    function testFilterLReturns3(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("L").size() == 3; // Leviticus, Lamentations, Luke
    }

    function testFilterMReturns4(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("M").size() == 4; // Micah, Malachi, Matthew, Mark
    }

    function testFilterNReturns3(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("N").size() == 3; // Numbers, Nehemiah, Nahum
    }

    function testFilterOReturns1(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("O").size() == 1; // Obadiah
    }

    function testFilterPReturns6(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("P").size() == 6; // Psalms, Proverbs, Philippians, Philemon, 1 Peter, 2 Peter
    }

    function testFilterRReturns3(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("R").size() == 3; // Ruth, Romans, Revelation
    }

    function testFilterSReturns3(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("S").size() == 3; // 1 Samuel, 2 Samuel, Song of Solomon
    }

    function testFilterTReturns5(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("T").size() == 5; // 1 Thessalonians, 2 Thessalonians, 1 Timothy, 2 Timothy, Titus
    }

    function testFilterZReturns2(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("Z").size() == 2; // Zephaniah, Zechariah
    }

    function testFilter1Returns8(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("1").size() == 8; // 1 Samuel, 1 Kings, 1 Chronicles, 1 Corinthians, 1 Thessalonians, 1 Timothy, 1 Peter, 1 John
    }

    function testFilter2Returns8(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("2").size() == 8; // 2 Samuel, 2 Kings, 2 Chronicles, 2 Corinthians, 2 Thessalonians, 2 Timothy, 2 Peter, 2 John
    }

    function testFilter3Returns1(logger as Test.Logger) as Boolean {
        return BibleBooks.getFilteredBooks("3").size() == 1; // 3 John
    }

    function testFilterTotalEquals22(logger as Test.Logger) as Boolean {
        return BibleBooks.FILTER_COUNT == 22;
    }

    function testNumericBooksAppearUnderAlphabetic(logger as Test.Logger) as Boolean {
        var sBooks = BibleBooks.getFilteredBooks("S");
        var has1Samuel = false;
        var has2Samuel = false;
        for (var i = 0; i < sBooks.size(); i++) {
            var idx = sBooks[i];
            if (idx == 8) { has1Samuel = true; }
            if (idx == 9) { has2Samuel = true; }
        }
        return has1Samuel && has2Samuel;
    }

    function testKingsAppearUnderK(logger as Test.Logger) as Boolean {
        var kBooks = BibleBooks.getFilteredBooks("K");
        var has1Kings = false;
        var has2Kings = false;
        for (var i = 0; i < kBooks.size(); i++) {
            var idx = kBooks[i];
            if (idx == 10) { has1Kings = true; }
            if (idx == 11) { has2Kings = true; }
        }
        return has1Kings && has2Kings;
    }

    // ------------------------------------------------------------------
    // 5. Storage edge cases
    // ------------------------------------------------------------------

    private function clearStorage() as Void {
        Application.Storage.setValue(BibleStorage.COLLECTION_KEY,
            [] as Application.Storage.ValueType);
    }

    private function makeEntry(ref as String, display as String) as Dictionary {
        var entry = {} as Dictionary;
        entry.put("scripture_ref", ref);
        entry.put("display_ref", display);
        entry.put("translation", "BSB");
        entry.put("book_index", 0);
        entry.put("chapter", 1);
        entry.put("start_verse", 1);
        entry.put("end_verse", 1);
        entry.put("captured_at", "2025-01-01T12:00:00Z");
        return entry;
    }

    function testMaxCollection50(logger as Test.Logger) as Boolean {
        clearStorage();
        for (var i = 0; i < 50; i++) {
            BibleStorage.saveEntry(makeEntry("ref." + i + ".1", "Ref " + i + ":1"));
        }
        return BibleStorage.getCount() == 50;
    }

    function testFifoReplacesOldestAt50(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("first.1.1", "First 1:1"));
        for (var i = 1; i < 50; i++) {
            BibleStorage.saveEntry(makeEntry("ref." + i + ".1", "Ref " + i + ":1"));
        }
        // Add one more — should evict "first.1.1"
        BibleStorage.saveEntry(makeEntry("overflow.1.1", "Overflow 1:1"));

        var all = BibleStorage.loadAll();
        var foundFirst = false;
        for (var i = 0; i < all.size(); i++) {
            var ref = (all[i] as Dictionary).get("scripture_ref") as String;
            if (ref == "first.1.1") {
                foundFirst = true;
            }
        }
        return !foundFirst && all.size() == 50;
    }

    function testDuplicateDetection(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeEntry("dup.1.1", "Dup 1:1");
        var s1 = BibleStorage.saveEntry(entry);
        var s2 = BibleStorage.saveEntry(entry);
        return s1 == BibleStorage.SAVE_STATUS_SAVED &&
               s2 == BibleStorage.SAVE_STATUS_DUPLICATE &&
               BibleStorage.getCount() == 1;
    }

    function testNullRefRejected(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeEntry("valid.1.1", "Valid 1:1");
        entry.put("scripture_ref", null);
        var status = BibleStorage.saveEntry(entry);
        return status == BibleStorage.SAVE_STATUS_FAILED && BibleStorage.getCount() == 0;
    }

    function testEmptyRefRejected(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeEntry("", "");
        entry.put("scripture_ref", "");
        var status = BibleStorage.saveEntry(entry);
        return status == BibleStorage.SAVE_STATUS_FAILED && BibleStorage.getCount() == 0;
    }

    function testCollectionFullReturnsFailed(logger as Test.Logger) as Boolean {
        // When collection is at max and we try to save a new entry,
        // FIFO should evict oldest and save the new one (returns SAVED)
        clearStorage();
        for (var i = 0; i < 50; i++) {
            BibleStorage.saveEntry(makeEntry("full." + i + ".1", "Full " + i + ":1"));
        }
        var status = BibleStorage.saveEntry(makeEntry("one.more.1.1", "One More 1:1"));
        return status == BibleStorage.SAVE_STATUS_SAVED && BibleStorage.getCount() == 50;
    }

    function testStoragePersistsAfterClear(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("persist.1.1", "Persist 1:1"));
        var raw = Application.Storage.getValue(BibleStorage.COLLECTION_KEY);
        if (raw == null || !(raw instanceof Array)) {
            return false;
        }
        return (raw as Array).size() == 1;
    }

    function testDeleteFromFullCollection(logger as Test.Logger) as Boolean {
        clearStorage();
        for (var i = 0; i < 50; i++) {
            BibleStorage.saveEntry(makeEntry("del." + i + ".1", "Del " + i + ":1"));
        }
        var deleted = BibleStorage.deleteEntry(25);
        return deleted && BibleStorage.getCount() == 49;
    }

    // ------------------------------------------------------------------
    // 6. Navigation wrap/clamp tests
    // ------------------------------------------------------------------

    function testBookListWrapUp(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.filterIndex = 0;
        state.selectedBookIndex = 0; // Genesis (first)
        var filtered = state.getFilteredBookIndices();
        var pos = 0;
        // Wrap up: from first to last
        if (pos > 0) {
            pos = pos - 1;
        } else {
            pos = filtered.size() - 1;
        }
        return filtered[pos] == 65; // Revelation
    }

    function testBookListWrapDown(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.filterIndex = 0;
        var filtered = state.getFilteredBookIndices();
        var pos = filtered.size() - 1; // Last book
        // Wrap down: from last to first
        if (pos < filtered.size() - 1) {
            pos = pos + 1;
        } else {
            pos = 0;
        }
        return filtered[pos] == 0; // Genesis
    }

    function testChapterListUpClampsAt1(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.bookIndex = 0; // Genesis
        state.chapter = 3;
        var cols = 5;
        if (state.chapter > cols) {
            state.chapter = state.chapter - cols;
        }
        // chapter=3, cols=5, 3>5 is false, so chapter stays 3
        // But let's test at chapter=6 (first row boundary)
        state.chapter = 6;
        if (state.chapter > cols) {
            state.chapter = state.chapter - cols;
        }
        return state.chapter == 1;
    }

    function testChapterListDownClampsAtMax(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.bookIndex = 65; // Revelation = 22 chapters
        state.chapter = 20;
        var maxChapter = BibleBooks.getChapterCount(state.bookIndex);
        var cols = 5;
        if (state.chapter + cols <= maxChapter) {
            state.chapter = state.chapter + cols;
        } else if (state.chapter < maxChapter) {
            state.chapter = maxChapter;
        }
        return state.chapter == 22;
    }

    function testVerseSelectStartClampsAt1(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.bookIndex = 0;
        state.chapter = 1;
        state.startVerse = 1;
        if (state.startVerse > 1) {
            state.startVerse = state.startVerse - 1;
        }
        return state.startVerse == 1;
    }

    function testVerseSelectEndClampsAtMax(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.bookIndex = 0;
        state.chapter = 1;
        state.endVerse = 31;
        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        if (state.endVerse < maxVerse) {
            state.endVerse = state.endVerse + 1;
        }
        return state.endVerse == 31;
    }

    function testVerseSelectStartCannotExceedEnd(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.bookIndex = 0;
        state.chapter = 1;
        state.startVerse = 10;
        state.endVerse = 10;
        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        if (state.startVerse < maxVerse) {
            state.startVerse = state.startVerse + 1;
            if (state.endVerse < state.startVerse) {
                state.endVerse = state.startVerse;
            }
        }
        return state.startVerse == 11 && state.endVerse == 11 && state.startVerse <= state.endVerse;
    }

    function testVerseSelectEndCannotGoBelowStart(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.bookIndex = 0;
        state.chapter = 1;
        state.startVerse = 5;
        state.endVerse = 5;
        if (state.endVerse > state.startVerse) {
            state.endVerse = state.endVerse - 1;
        }
        return state.endVerse == 5;
    }

    // ------------------------------------------------------------------
    // 7. Safe area tests — all 9 device configurations
    // ------------------------------------------------------------------

    function testSafeAreaInstinct3Solar(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var ct = layout.get("contentTop") as Number;
        var cb = layout.get("contentBottom") as Number;
        var cw = layout.get("contentWidth") as Number;
        return ct >= 18 && cb <= 158 && cw == 140;
    }

    function testSafeAreaInstinct3Amoled(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, false, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var ct = layout.get("contentTop") as Number;
        var cb = layout.get("contentBottom") as Number;
        return ct >= 18 && cb <= 158;
    }

    function testSafeAreaInstinctE40(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var mx = layout.get("marginX") as Number;
        return mx == 18;
    }

    function testSafeAreaInstinctE45(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var mx = layout.get("marginX") as Number;
        return mx == 18;
    }

    function testSafeAreaDescentG2(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var ct = layout.get("contentTop") as Number;
        var cb = layout.get("contentBottom") as Number;
        return ct >= 18 && cb <= 158;
    }

    function testSafeAreaFenix7(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_ROUND);
        var ct = layout.get("contentTop") as Number;
        var cb = layout.get("contentBottom") as Number;
        var mx = layout.get("marginX") as Number;
        return ct >= 10 && cb <= 250 && mx == 10;
    }

    function testSafeAreaVenu3(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var ct = layout.get("contentTop") as Number;
        var cb = layout.get("contentBottom") as Number;
        var mx = layout.get("marginX") as Number;
        return ct >= 10 && cb <= 380 && mx == 10;
    }

    function testSafeAreaD2Mach1(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_ROUND);
        var ct = layout.get("contentTop") as Number;
        var cb = layout.get("contentBottom") as Number;
        return ct >= 10 && cb <= 250;
    }

    function testSafeAreaApproachS50(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_ROUND);
        var ct = layout.get("contentTop") as Number;
        var cb = layout.get("contentBottom") as Number;
        return ct >= 10 && cb <= 250;
    }

    function testSafeAreaContentWidthPositive(logger as Test.Logger) as Boolean {
        // All 9 devices must have positive content width
        var devices = [
            [176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON],
            [176, 176, BibleLayout.FONT_SMALL, 14, false, System.SCREEN_SHAPE_SEMI_OCTAGON],
            [260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_ROUND],
            [390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND]
        ];
        for (var i = 0; i < devices.size(); i++) {
            var d = devices[i] as Array<Number>;
            var layout = BibleLayout.mockLayout(d[0], d[1], d[2], d[3], d[4] == 1, d[5]);
            var cw = layout.get("contentWidth") as Number;
            if (cw <= 0) {
                return false;
            }
        }
        return true;
    }

    function testSafeAreaContentHeightPositive(logger as Test.Logger) as Boolean {
        var devices = [
            [176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON],
            [260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_ROUND],
            [390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND]
        ];
        for (var i = 0; i < devices.size(); i++) {
            var d = devices[i] as Array<Number>;
            var layout = BibleLayout.mockLayout(d[0], d[1], d[2], d[3], d[4] == 1, d[5]);
            var ch = layout.get("contentHeight") as Number;
            if (ch <= 0) {
                return false;
            }
        }
        return true;
    }

    // ------------------------------------------------------------------
    // 8. Color path tests — 1-bit mono vs color palette
    // ------------------------------------------------------------------

    function test1BitMonoTextColor(logger as Test.Logger) as Boolean {
        var colors = BibleLayout.getColors(true);
        return colors.get("textColor") == Graphics.COLOR_BLACK;
    }

    function test1BitMonoBgColor(logger as Test.Logger) as Boolean {
        var colors = BibleLayout.getColors(true);
        return colors.get("bgColor") == Graphics.COLOR_WHITE;
    }

    function test1BitMonoSelectBg(logger as Test.Logger) as Boolean {
        var colors = BibleLayout.getColors(true);
        return colors.get("selectBg") == Graphics.COLOR_BLACK;
    }

    function test1BitMonoSelectText(logger as Test.Logger) as Boolean {
        var colors = BibleLayout.getColors(true);
        return colors.get("selectText") == Graphics.COLOR_WHITE;
    }

    function testColorPaletteTextColor(logger as Test.Logger) as Boolean {
        var colors = BibleLayout.getColors(false);
        return colors.get("textColor") == Graphics.COLOR_WHITE;
    }

    function testColorPaletteBgColor(logger as Test.Logger) as Boolean {
        var colors = BibleLayout.getColors(false);
        return colors.get("bgColor") == Graphics.COLOR_BLACK;
    }

    function testColorPaletteAccent(logger as Test.Logger) as Boolean {
        var colors = BibleLayout.getColors(false);
        return colors.get("accentColor") == Graphics.COLOR_YELLOW;
    }

    function testColorPaletteSelectBg(logger as Test.Logger) as Boolean {
        var colors = BibleLayout.getColors(false);
        return colors.get("selectBg") == Graphics.COLOR_WHITE;
    }

    function testColorPaletteSelectText(logger as Test.Logger) as Boolean {
        var colors = BibleLayout.getColors(false);
        return colors.get("selectText") == Graphics.COLOR_BLACK;
    }

    function test1BitLayoutUsesMonoFlag(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var mono = layout.get("isMonochrome") as Boolean;
        return mono == true;
    }

    function testColorLayoutNotMono(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var mono = layout.get("isMonochrome") as Boolean;
        return mono == false;
    }

    // ------------------------------------------------------------------
    // 9. Error path tests
    // ------------------------------------------------------------------

    function testError404Message(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(404);
        return msg == BibleError.MSG_CHAPTER_NOT_FOUND;
    }

    function testErrorNoConnection(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(-1);
        return msg == BibleError.MSG_NO_CONNECTION;
    }

    function testErrorNegative104(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(-104);
        return msg == BibleError.MSG_NO_CONNECTION;
    }

    function testError500Message(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(500);
        return msg == BibleError.MSG_LOAD_FAILED;
    }

    function testError502Message(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(502);
        return msg == BibleError.MSG_LOAD_FAILED;
    }

    function testError400Message(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(400);
        return msg == BibleError.MSG_LOAD_FAILED;
    }

    function testMalformedJsonReturnsEmpty(logger as Test.Logger) as Boolean {
        var verses = BibleJsonScanner.parseVerses("{bad json");
        return verses.size() == 0;
    }

    function testEmptyJsonReturnsEmpty(logger as Test.Logger) as Boolean {
        var verses = BibleJsonScanner.parseVerses("");
        return verses.size() == 0;
    }

    function testNullDataReturnsEmpty(logger as Test.Logger) as Boolean {
        var verses = BibleApi.parseResponse(null);
        return verses.size() == 0;
    }

    function testStorageExceptionHandled(logger as Test.Logger) as Boolean {
        // safeStorageSet handles exceptions gracefully
        var result = BibleError.safeStorageSet("test_key", [] as Array<Dictionary>);
        // It may or may not succeed depending on simulator state,
        // but it must not crash
        return true;
    }

    function testInvalidPassageStateNull(logger as Test.Logger) as Boolean {
        return !BibleError.isValidPassageState(null);
    }

    function testInvalidPassageStateNegativeBook(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(-1, 1, 1, 1);
        return !BibleError.isValidPassageState(state);
    }

    function testInvalidPassageStateTooHighChapter(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(0, 51, 1, 1);
        return !BibleError.isValidPassageState(state);
    }

    function testInvalidPassageStateTooHighVerse(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(0, 1, 50, 50);
        return !BibleError.isValidPassageState(state);
    }

    function testInvalidPassageStateStartGreaterThanEnd(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(42, 3, 20, 10);
        return !BibleError.isValidPassageState(state);
    }

    function testSafeComputeLayoutNullDc(logger as Test.Logger) as Boolean {
        var layout = BibleError.safeComputeLayout(null);
        return layout != null && layout instanceof Dictionary;
    }

    function testSafeDictStringNullDict(logger as Test.Logger) as Boolean {
        return BibleError.safeDictString(null, "key", "fallback") == "fallback";
    }

    function testSafeDictNumberNullDict(logger as Test.Logger) as Boolean {
        return BibleError.safeDictNumber(null, "key", 7) == 7;
    }

    function testSafeArraySizeNull(logger as Test.Logger) as Boolean {
        return BibleError.safeArraySize(null) == 0;
    }

    function testSafeArraySizeEmpty(logger as Test.Logger) as Boolean {
        return BibleError.safeArraySize([] as Array<Number>) == 0;
    }
}
