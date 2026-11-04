using Toybox.Application;
using Toybox.Lang;
using Toybox.Test;

//! Edge cases (Dylan 3:38 PM): bounds, odd chapters, corrupt storage, bookmarks, filters.

(:test)
function testBibleBoundsNoWrap(logger as Test.Logger) as Lang.Boolean {
    Test.assert(ChapterNav.prevChapter(0, 1) == null);   // Genesis 1: nothing before
    Test.assert(ChapterNav.nextChapter(65, 22) == null); // Revelation 22: nothing after
    Test.assert(ChapterNav.isBibleStart(0, 1));
    Test.assert(ChapterNav.isBibleEnd(65, 22));
    return true;
}

(:test)
function testSingleChapterBooks(logger as Test.Logger) as Lang.Boolean {
    // Obadiah 30, Philemon 56, 2 John 62, 3 John 63, Jude 64
    var one = [30, 56, 62, 63, 64];
    var i;
    for (i = 0; i < one.size(); i++) {
        var b = one[i] as Lang.Number;
        Test.assertEqual(Books.chapterCount(b), 1);
        var n = ChapterNav.nextChapter(b, 1);
        Test.assert(n != null && n.book == b + 1 && n.chapter == 1);
        var p = ChapterNav.prevChapter(b, 1);
        Test.assert(p != null && p.book == b - 1 && p.chapter == Books.chapterCount(b - 1));
    }
    return true;
}

(:test)
function testOddChapters(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ContentLoader.verseCount(18, 117), 2);   // shortest chapter
    Test.assertEqual(ContentLoader.verseCount(18, 119), 176); // longest chapter
    var t = ContentLoader.verseText(16, 8, 9);                 // Esther 8:9, longest verse
    Test.assert(t != null && (t as Lang.String).length() > 300);
    return true;
}

(:test)
function testMissingVersesKeepNumbering(logger as Test.Logger) as Lang.Boolean {
    // Matt 17:21 and Acts 8:37 are not in the BSB text.
    Test.assertEqual(ContentLoader.verseCount(39, 17), 27);
    var m = ContentLoader.verseNumbers(39, 17);
    Test.assertEqual(m.size(), 26);
    Test.assert(m.indexOf(21) < 0 && m.indexOf(22) >= 0);
    Test.assert(ContentLoader.verseText(39, 17, 22) != null);
    Test.assertEqual(ContentLoader.verseCount(43, 8), 40);
    Test.assert(ContentLoader.verseNumbers(43, 8).indexOf(37) < 0);
    return true;
}

(:test)
function testEveryFilterOption(logger as Test.Logger) as Lang.Boolean {
    var expect = [66, 2, 1, 2, 6, 2, 4, 1, 9, 0, 3, 4, 3, 1, 4, 3, 1, 1, 2, 17, 17, 17];
    var i;
    for (i = 0; i < expect.size(); i++) {
        Test.assertEqual(PickList.booksForFilter(i).size(), expect[i]);
    }
    return true;
}

(:test)
function testBookmarkToggleNoDuplicateAndFull(logger as Test.Logger) as Lang.Boolean {
    Bookmarks.save([] as Lang.Array);
    Test.assertEqual(Bookmarks.toggle(42, 3, 16), :added);
    Test.assertEqual(Bookmarks.toggle(42, 3, 16), :removed); // same verse twice = toggle off
    Test.assertEqual(Bookmarks.load().size(), 0);
    // Book boundary: Malachi 4:6 and Matthew 1:1 are distinct
    Bookmarks.toggle(38, 4, 6);
    Bookmarks.toggle(39, 1, 1);
    Test.assertEqual(Bookmarks.load().size(), 2);
    Bookmarks.save([] as Lang.Array);
    var i;
    // Full list (sized for a synced library): filled directly, not by thousands of toggles.
    var full = [] as Lang.Array;
    for (i = 0; i < Bookmarks.MAX_DEFAULT; i++) {
        full.add(Bookmarks.pack(i % 66, 1, 1 + i / 66));
    }
    Bookmarks.save(full);
    Test.assertEqual(Bookmarks.toggle(18, 119, 100), :full);
    Test.assertEqual(Bookmarks.load().size(), Bookmarks.MAX_DEFAULT);
    Bookmarks.save([] as Lang.Array);
    return true;
}

(:test)
function testCorruptStorageIgnored(logger as Test.Logger) as Lang.Boolean {
    Application.Storage.setValue("last", ["x", 2, 3]);
    Test.assert(LastReadApp.stored() == null);
    Application.Storage.setValue("last", [70, 1, 1]);   // out of range book
    Test.assert(LastReadApp.stored() == null);
    Application.Storage.setValue("last", [18, 151, 1]); // Psalm 151 does not exist
    Test.assert(LastReadApp.stored() == null);
    Application.Storage.setValue("last", [42, 3, 16]);
    Test.assert(LastReadApp.stored() != null);
    Test.assertEqual(LastReadApp.chapterFor(42), 3);
    Application.Storage.deleteValue("last");
    // Bookmarks: junk entries dropped, duplicates collapsed
    Bookmarks._cache = null;
    Application.Storage.setValue(Bookmarks.STORAGE_KEY, ["bad", 3.5, Bookmarks.pack(42, 3, 16),
        Bookmarks.pack(42, 3, 16), Bookmarks.pack(99, 1, 1), Bookmarks.pack(18, 200, 1)]);
    Test.assertEqual(Bookmarks.load().size(), 1);
    Bookmarks.save([] as Lang.Array);
    // Scroll mode / theme junk -> defaults
    Application.Storage.setValue(ScrollModel.STORAGE_KEY, "line");
    var st = new ScrollModel.State();
    Test.assertEqual(st.loadMode(), ScrollModel.MODE_VERSE);
    Application.Storage.setValue(ScrollModel.STORAGE_KEY, 7);
    Test.assertEqual(st.loadMode(), ScrollModel.MODE_VERSE);
    Application.Storage.deleteValue(ScrollModel.STORAGE_KEY);
    Application.Storage.setValue(Palette.STORAGE_KEY, "light");
    Palette.loadTheme();
    Test.assertEqual(Palette.theme, Palette.THEME_DARK);
    Application.Storage.deleteValue(Palette.STORAGE_KEY);
    return true;
}

//! Regression (edgeB mash): taps that land within SETTLE_MS of the reader appearing were
//! aimed at the grid and must not open the reader menu; later taps must.
(:test)
function testInputGateSettle(logger as Test.Logger) as Lang.Boolean {
    Test.assert(!InputGate.accept(1000, 1000));
    Test.assert(!InputGate.accept(1000, 1000 + InputGate.SETTLE_MS - 1));
    Test.assert(InputGate.accept(1000, 1000 + InputGate.SETTLE_MS));
    return true;
}

//! Regression (Too Many Timers): ChapterGridView ignores every open path while a tap flash
//! is pending, so a mash opens exactly one reader.
(:test)
function testGridFlashBlocksSecondOpen(logger as Test.Logger) as Lang.Boolean {
    var v = new ChapterGridView();
    v.flashIdx = 3;
    var d = new ChapterGridDelegate();
    Test.assert(v.flashIdx == 3);
    // flashAndOpen is a no-op while a flash is pending
    v.flashAndOpen(5);
    Test.assertEqual(v.flashIdx, 3);
    return true;
}

//! Regression (edgeB B17): relaunch restores book, chapter AND the verse to resume at.
//! (ReaderView.onLayout used to reset scrollOffset after the resume jump.)
(:test)
function testRestoreResumeVerse(logger as Test.Logger) as Lang.Boolean {
    Application.Storage.setValue("last", [42, 6, 2]);
    LastReadApp.restore();
    Test.assertEqual(AppState.selectedBook, 42);
    Test.assertEqual(AppState.selectedChapter, 6);
    Test.assertEqual(LastReadApp.resumeVerse, 2);
    LastReadApp.resumeVerse = 0;
    LastReadApp.pending = null;
    Application.Storage.deleteValue("last");
    return true;
}

//! Edge pass D12: a drag focus left by the home list must not leak into the next list.
(:test)
function testStaleDragFocusDropsOnNewList(logger as Test.Logger) as Lang.Boolean {
    var home = ["a", "b", "c", "d", "e", "f", "g", "h"] as Lang.Array;
    var other = ["x", "y", "z"] as Lang.Array;
    PickList._cLabels = home;
    PickList._focusOut = 6;
    Test.assert(PickList.takeFocus(0, other) == 0); // stale 6 dropped
    PickList._cLabels = home;
    PickList._focusOut = 5;
    Test.assert(PickList.takeFocus(0, home) == 5);  // same list: drag focus wins
    Test.assert(PickList.takeFocus(9, other) == 2); // clamped into range
    PickList._cLabels = null;
    return true;
}

//! v4 settings persist through Application.Storage (kill + relaunch reads them back).
(:test)
function testSettingsPersist(logger as Test.Logger) as Lang.Boolean {
    Application.Storage.deleteValue(Feedback.STORAGE_KEY);
    Test.assert(Feedback.enabled());           // default on
    Feedback.setEnabled(false);
    Test.assert(!Feedback.enabled());
    Application.Storage.setValue(Feedback.STORAGE_KEY, "junk");
    Test.assert(Feedback.enabled());           // corrupt -> default
    Application.Storage.deleteValue(Feedback.STORAGE_KEY);
    var m0 = AppState.scroll.mode;
    NativeLists.applySetting(:scroll, m0 != ScrollModel.MODE_VERSE);
    Test.assert(AppState.scroll.mode != m0);
    Test.assert(AppState.scroll.loadMode() == AppState.scroll.mode); // stored
    NativeLists.applySetting(:scroll, m0 == ScrollModel.MODE_VERSE);
    Test.assert(AppState.scroll.mode == m0);
    return true;
}
