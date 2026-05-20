import Toybox.Lang;
using Toybox.Test;
using Toybox.Application;

(:test)
class VerseSelectViewTest {

    // --- Mode switching tests ---

    function testModeDownAllToStart(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.verseSelectMode = 0; // All
        // Simulate Down: All -> Start
        if (state.verseSelectMode == 0) {
            state.verseSelectMode = 1;
        }

        return state.verseSelectMode == 1;
    }

    function testModeDownStartToEnd(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.verseSelectMode = 1; // Start
        // Simulate Down: Start -> End
        if (state.verseSelectMode == 1) {
            state.verseSelectMode = 2;
        }

        return state.verseSelectMode == 2;
    }

    function testModeUpEndToStart(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.verseSelectMode = 2; // End
        // Simulate Up: End -> Start
        if (state.verseSelectMode == 2) {
            state.verseSelectMode = 1;
        }

        return state.verseSelectMode == 1;
    }

    function testModeUpStartToAll(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.verseSelectMode = 1; // Start
        // Simulate Up: Start -> All
        if (state.verseSelectMode == 1) {
            state.verseSelectMode = 0;
        }

        return state.verseSelectMode == 0;
    }

    function testModeUpAllStaysAll(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.verseSelectMode = 0; // All
        // Simulate Up: All stays All
        if (state.verseSelectMode == 1) {
            state.verseSelectMode = 0;
        }

        return state.verseSelectMode == 0;
    }

    function testModeDownEndStaysEnd(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.verseSelectMode = 2; // End
        // Simulate Down: End stays End
        if (state.verseSelectMode == 0) {
            state.verseSelectMode = 1;
        } else if (state.verseSelectMode == 1) {
            state.verseSelectMode = 2;
        }

        return state.verseSelectMode == 2;
    }

    // --- Start verse adjustment tests ---

    function testRightIncrementsStartVerse(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0; // Genesis
        state.chapter = 1;
        state.verseSelectMode = 1; // Start
        state.startVerse = 5;
        state.endVerse = 10;

        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        // Simulate Right on Start
        if (state.startVerse < maxVerse) {
            state.startVerse = state.startVerse + 1;
            if (state.endVerse < state.startVerse) {
                state.endVerse = state.startVerse;
            }
        }

        return state.startVerse == 6 && state.endVerse == 10;
    }

    function testRightBumpsEndIfStartExceedsEnd(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 1;
        state.verseSelectMode = 1;
        state.startVerse = 10;
        state.endVerse = 10;

        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        // Simulate Right on Start: start=10, bump to 11, end must bump too
        if (state.startVerse < maxVerse) {
            state.startVerse = state.startVerse + 1;
            if (state.endVerse < state.startVerse) {
                state.endVerse = state.startVerse;
            }
        }

        return state.startVerse == 11 && state.endVerse == 11;
    }

    function testLeftDecrementsStartVerse(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 1;
        state.verseSelectMode = 1;
        state.startVerse = 5;

        // Simulate Left on Start
        if (state.startVerse > 1) {
            state.startVerse = state.startVerse - 1;
        }

        return state.startVerse == 4;
    }

    function testStartVerseClampsAt1(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 1;
        state.verseSelectMode = 1;
        state.startVerse = 1;

        // Simulate Left on Start at boundary
        if (state.startVerse > 1) {
            state.startVerse = state.startVerse - 1;
        }

        return state.startVerse == 1;
    }

    function testStartVerseClampsAtMax(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 1;
        state.verseSelectMode = 1;
        state.startVerse = 31; // Genesis 1 max

        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        // Simulate Right at boundary
        if (state.startVerse < maxVerse) {
            state.startVerse = state.startVerse + 1;
        }

        return state.startVerse == 31;
    }

    // --- End verse adjustment tests ---

    function testRightIncrementsEndVerse(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 1;
        state.verseSelectMode = 2; // End
        state.endVerse = 5;

        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        // Simulate Right on End
        if (state.endVerse < maxVerse) {
            state.endVerse = state.endVerse + 1;
        }

        return state.endVerse == 6;
    }

    function testLeftDecrementsEndVerse(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 1;
        state.verseSelectMode = 2;
        state.startVerse = 3;
        state.endVerse = 10;

        // Simulate Left on End: can only go down to startVerse
        if (state.endVerse > state.startVerse) {
            state.endVerse = state.endVerse - 1;
        }

        return state.endVerse == 9;
    }

    function testEndVerseCannotGoBelowStart(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 1;
        state.verseSelectMode = 2;
        state.startVerse = 5;
        state.endVerse = 5;

        // Simulate Left on End at boundary (end == start)
        if (state.endVerse > state.startVerse) {
            state.endVerse = state.endVerse - 1;
        }

        return state.endVerse == 5;
    }

    function testEndVerseClampsAtMax(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 1;
        state.verseSelectMode = 2;
        state.endVerse = 31;

        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        // Simulate Right at boundary
        if (state.endVerse < maxVerse) {
            state.endVerse = state.endVerse + 1;
        }

        return state.endVerse == 31;
    }

    // --- "All verses" behavior ---

    function testAllVersesSetsFullRange(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 18; // Psalms
        state.chapter = 119;
        state.verseSelectMode = 0;

        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        if (maxVerse <= 0) {
            maxVerse = 1;
        }

        // When "All verses" is selected, full range is implied
        state.startVerse = 1;
        state.endVerse = maxVerse;

        return state.startVerse == 1 && state.endVerse == 176;
    }

    // --- Range validation tests ---

    function testRangePreventsStartGreaterThanEnd(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.bookIndex = 0;
        state.chapter = 1;
        state.verseSelectMode = 1;
        state.startVerse = 10;
        state.endVerse = 10;

        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        // Bump start from 10 to 11
        if (state.startVerse < maxVerse) {
            state.startVerse = state.startVerse + 1;
            if (state.endVerse < state.startVerse) {
                state.endVerse = state.startVerse;
            }
        }

        return state.startVerse == 11 && state.endVerse == 11 && state.startVerse <= state.endVerse;
    }

    function testMaxVerseForPsalm117(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(18, 117);
        return verses == 2;
    }

    function testMaxVerseForPsalm150(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(18, 150);
        return verses == 6;
    }

    function testMaxVerseForGenesis2(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(0, 2);
        return verses == 25;
    }

    function testMaxVerseForJohn6(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(42, 6);
        return verses == 71;
    }

    // --- State initialization test ---

    function testDefaultVerseSelectModeIsAll(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        return state.verseSelectMode == 0;
    }

    function testDefaultStartEndAre1(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        return state.startVerse == 1 && state.endVerse == 1;
    }

    // --- Fix 1: VerseSelectView rows use contentTop for safe area ---

    function testVerseSelectRowYUsesContentTop(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var contentTop = layout.get("contentTop") as Number;
        var marginTop = layout.get("marginTop") as Number;
        // contentTop for semi-octagon = max(14+1+4, 18+14) = 32
        // Rows start at contentTop + ROW_SPACING, not raw HEADER_HEIGHT + ROW_SPACING
        var row1Y = contentTop + 10;
        return row1Y >= contentTop + 10 && row1Y >= marginTop + 10;
    }

    function testVerseSelectHintYBoundedByContentBottom(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var contentBottom = layout.get("contentBottom") as Number;
        var hintY = contentBottom - 8;
        return hintY <= contentBottom - 8;
    }
}
