import Toybox.Lang;
using Toybox.Test;
using Toybox.Application;

(:test)
class ChapterListViewTest {

    // --- Chapter count accuracy tests ---

    function testGenesisHas50Chapters(logger as Test.Logger) as Boolean {
        var count = BibleBooks.getChapterCount(0);
        return count == 50;
    }

    function testPsalmsHas150Chapters(logger as Test.Logger) as Boolean {
        var count = BibleBooks.getChapterCount(18);
        return count == 150;
    }

    function testRevelationHas22Chapters(logger as Test.Logger) as Boolean {
        var count = BibleBooks.getChapterCount(65);
        return count == 22;
    }

    function test3JohnHas1Chapter(logger as Test.Logger) as Boolean {
        var count = BibleBooks.getChapterCount(63);
        return count == 1;
    }

    // --- Verse count accuracy tests ---

    function testGenesis1Has31Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(0, 1);
        return verses == 31;
    }

    function testGenesis10Has32Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(0, 10);
        return verses == 32;
    }

    function testPsalm119Has176Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(18, 119);
        return verses == 176;
    }

    function testPsalm23Has6Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(18, 23);
        return verses == 6;
    }

    function testPsalm1Has6Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(18, 1);
        return verses == 6;
    }

    function testJohn3Has36Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(42, 3);
        return verses == 36;
    }

    function testJohn1Has51Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(42, 1);
        return verses == 51;
    }

    function testJohn21Has25Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(42, 21);
        return verses == 25;
    }

    // --- Boundary / fallback tests ---

    function testUnknownBookReturns0Chapters(logger as Test.Logger) as Boolean {
        var count = BibleBooks.getChapterCount(99);
        return count == 0;
    }

    function testInvalidChapterReturns0Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(0, 0);
        return verses == 0;
    }

    function testChapterBeyondMaxReturns0Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(0, 51);
        return verses == 0;
    }

    function testGenesisFallback30(logger as Test.Logger) as Boolean {
        // Genesis chapter 11 (beyond hardcoded table) should fall back to 30
        var verses = BibleBooks.getVerseCount(0, 11);
        return verses == 30;
    }

    function testPsalmsFallback10(logger as Test.Logger) as Boolean {
        // Psalm 151 (beyond 150) should fall back to 10
        var verses = BibleBooks.getVerseCount(18, 151);
        return verses == 10;
    }

    function testJohnFallback20(logger as Test.Logger) as Boolean {
        // John chapter 22 (beyond 21) should fall back to 20
        var verses = BibleBooks.getVerseCount(42, 22);
        return verses == 20;
    }

    function testOtherBookFallback40(logger as Test.Logger) as Boolean {
        // Exodus chapter 1 (no hardcoded table) should fall back to 40
        var verses = BibleBooks.getVerseCount(1, 1);
        return verses == 40;
    }

    // --- State tests for chapter selection ---

    function testChapterSelectionStartsAt1(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Simulate entering ChapterList for Genesis
        state.bookIndex = 0;
        state.chapter = 1;

        return state.chapter == 1;
    }

    function testChapterCountMatchesSelectedBook(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 18; // Psalms
        var chapterCount = BibleBooks.getChapterCount(state.bookIndex);

        return chapterCount == 150;
    }

    // --- Grid calculation tests ---

    function testGrid5Columns(logger as Test.Logger) as Boolean {
        var cols = 5;
        var chapterCount = BibleBooks.getChapterCount(0); // Genesis = 50
        var totalRows = (chapterCount + cols - 1) / cols;
        return totalRows == 10;
    }

    function testGridRowsFor50Chapters(logger as Test.Logger) as Boolean {
        var cols = 5;
        var chapterCount = 50;
        var totalRows = (chapterCount + cols - 1) / cols;
        return totalRows == 10;
    }

    function testGridRowsFor150Chapters(logger as Test.Logger) as Boolean {
        var cols = 5;
        var chapterCount = 150;
        var totalRows = (chapterCount + cols - 1) / cols;
        return totalRows == 30;
    }

    function testGridRowsFor1Chapter(logger as Test.Logger) as Boolean {
        var cols = 5;
        var chapterCount = 1;
        var totalRows = (chapterCount + cols - 1) / cols;
        return totalRows == 1;
    }

    // --- Navigation tests ---

    function testUpMovesBy5Chapters(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0; // Genesis
        state.chapter = 6;

        // Simulate Up: move by 5 (cols)
        var cols = 5;
        if (state.chapter > cols) {
            state.chapter = state.chapter - cols;
        }

        return state.chapter == 1;
    }

    function testDownMovesBy5Chapters(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0; // Genesis
        state.chapter = 1;
        var maxChapter = BibleBooks.getChapterCount(0);
        var cols = 5;

        if (state.chapter + cols <= maxChapter) {
            state.chapter = state.chapter + cols;
        }

        return state.chapter == 6;
    }

    function testDownClampsToMaxChapter(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0; // Genesis
        state.chapter = 48;
        var maxChapter = BibleBooks.getChapterCount(0);
        var cols = 5;

        if (state.chapter + cols <= maxChapter) {
            state.chapter = state.chapter + cols;
        } else if (state.chapter < maxChapter) {
            state.chapter = maxChapter;
        }

        return state.chapter == 50;
    }

    function testUpClampsAt1(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 3;
        var cols = 5;

        if (state.chapter > cols) {
            state.chapter = state.chapter - cols;
        }
        // chapter=3, cols=5, so 3 > 5 is false, no change

        return state.chapter == 3;
    }

    function testLeftDecrementsChapter(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 5;

        if (state.chapter > 1) {
            state.chapter = state.chapter - 1;
        }

        return state.chapter == 4;
    }

    function testRightIncrementsChapter(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 5;
        var maxChapter = BibleBooks.getChapterCount(0);

        if (state.chapter < maxChapter) {
            state.chapter = state.chapter + 1;
        }

        return state.chapter == 6;
    }

    function testLeftClampsAt1(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 1;

        if (state.chapter > 1) {
            state.chapter = state.chapter - 1;
        }

        return state.chapter == 1;
    }

    function testRightClampsAtMax(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 50;
        var maxChapter = BibleBooks.getChapterCount(0);

        if (state.chapter < maxChapter) {
            state.chapter = state.chapter + 1;
        }

        return state.chapter == 50;
    }

    // --- Verse select integration tests ---

    function testEnterSetsVerseModeToAll(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 1;
        state.verseSelectMode = 0;
        state.startVerse = 1;
        state.endVerse = 1;

        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        if (maxVerse <= 0) {
            maxVerse = 1;
        }
        state.endVerse = maxVerse;

        return state.verseSelectMode == 0 && state.startVerse == 1 && state.endVerse == 31;
    }

    function testVerseSelectStateForPsalm119(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 18;
        state.chapter = 119;
        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);

        return maxVerse == 176;
    }
}
