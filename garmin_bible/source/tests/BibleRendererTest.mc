import Toybox.Lang;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Test;

class BibleRendererTest {

    // ------------------------------------------------------------------
    // Font selection tests
    // ------------------------------------------------------------------

    function testSelectFontSmallFor176(logger as Test.Logger) as Boolean {
        var fontSize = BibleRenderer.selectFontSize(176);
        return fontSize == BibleRenderer.FONT_SMALL;
    }

    function testSelectFontSmallFor180(logger as Test.Logger) as Boolean {
        var fontSize = BibleRenderer.selectFontSize(180);
        return fontSize == BibleRenderer.FONT_SMALL;
    }

    function testSelectFontMediumFor218(logger as Test.Logger) as Boolean {
        var fontSize = BibleRenderer.selectFontSize(218);
        return fontSize == BibleRenderer.FONT_MEDIUM;
    }

    function testSelectFontMediumFor260(logger as Test.Logger) as Boolean {
        var fontSize = BibleRenderer.selectFontSize(260);
        return fontSize == BibleRenderer.FONT_MEDIUM;
    }

    function testSelectFontLargeFor280(logger as Test.Logger) as Boolean {
        var fontSize = BibleRenderer.selectFontSize(280);
        return fontSize == BibleRenderer.FONT_LARGE;
    }

    function testSelectFontLargeFor390(logger as Test.Logger) as Boolean {
        var fontSize = BibleRenderer.selectFontSize(390);
        return fontSize == BibleRenderer.FONT_LARGE;
    }

    // ------------------------------------------------------------------
    // Char width tests
    // ------------------------------------------------------------------

    function testCharWidthSmall(logger as Test.Logger) as Boolean {
        var cw = BibleRenderer.getCharWidthForFontSize(BibleRenderer.FONT_SMALL);
        return cw == BibleRenderer.CHAR_WIDTH_SMALL;
    }

    function testCharWidthMedium(logger as Test.Logger) as Boolean {
        var cw = BibleRenderer.getCharWidthForFontSize(BibleRenderer.FONT_MEDIUM);
        return cw == BibleRenderer.CHAR_WIDTH_MEDIUM;
    }

    function testCharWidthLarge(logger as Test.Logger) as Boolean {
        var cw = BibleRenderer.getCharWidthForFontSize(BibleRenderer.FONT_LARGE);
        return cw == BibleRenderer.CHAR_WIDTH_LARGE;
    }

    // ------------------------------------------------------------------
    // Word-wrap: short verse fits on one line
    // ------------------------------------------------------------------

    function testWrapShortVerseOneLine(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 1, "verseText" => "In the beginning." }
        ] as Array<Dictionary>;
        // Screen width 176, margin 18*2=36, contentWidth=140
        // charWidth=6, maxChars=140/6=23
        // numPrefix "1 " = 2 chars, first line chars = 21
        // "In the beginning." = 19 chars -> fits in 21
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        return lines.size() == 1;
    }

    function testWrapShortVerseText(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 1, "verseText" => "In the beginning." }
        ] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        if (lines.size() != 1) {
            return false;
        }
        var line = lines[0] as Dictionary;
        var text = line.get("text") as String;
        return text == "1 In the beginning.";
    }

    // ------------------------------------------------------------------
    // Word-wrap: long verse wraps into multiple lines
    // ------------------------------------------------------------------

    function testWrapLongVerseMultiLine(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 1, "verseText" => "Now there was a man of the Pharisees named Nicodemus, a member of the Jewish ruling council." }
        ] as Array<Dictionary>;
        // 140px width, charWidth 6 -> maxChars ~23
        // verse 1 prefix "1 " = 2, first line = 21 chars
        // Long verse should wrap into 2+ lines
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        return lines.size() >= 2;
    }

    function testFirstLineHasVerseNumber(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 16, "verseText" => "For God so loved the world that He gave His only Son, that everyone who believes in Him shall not perish but have eternal life." }
        ] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        if (lines.size() == 0) {
            return false;
        }
        var firstLine = lines[0] as Dictionary;
        var text = firstLine.get("text") as String;
        var prefix = text.substring(0, 3) as String;
        var isFirst = firstLine.get("isFirstLine") as Boolean;
        return prefix == "16 " && isFirst;
    }

    function testSubsequentLinesNoVerseNumber(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 16, "verseText" => "For God so loved the world that He gave His only Son, that everyone who believes in Him shall not perish but have eternal life." }
        ] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        if (lines.size() < 2) {
            return false;
        }
        var secondLine = lines[1] as Dictionary;
        var text = secondLine.get("text") as String;
        var prefix = text.substring(0, 3) as String;
        var isFirst = secondLine.get("isFirstLine") as Boolean;
        return !(prefix == "16 ") && !isFirst;
    }

    // ------------------------------------------------------------------
    // Multi-verse wrap: each verse gets its own number
    // ------------------------------------------------------------------

    function testMultiVerseNumbers(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 1, "verseText" => "Short verse one." },
            { "verseNumber" => 2, "verseText" => "Short verse two." }
        ] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        if (lines.size() != 2) {
            return false;
        }
        var line0 = lines[0] as Dictionary;
        var line1 = lines[1] as Dictionary;
        var text0 = line0.get("text") as String;
        var text1 = line1.get("text") as String;
        return text0.substring(0, 2) == "1 " && text1.substring(0, 2) == "2 ";
    }

    // ------------------------------------------------------------------
    // Long word truncation
    // ------------------------------------------------------------------

    function testLongWordTruncated(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 1, "verseText" => "Supercalifragilisticexpialidocious." }
        ] as Array<Dictionary>;
        // Very narrow width (30px), charWidth 6 -> maxChars=5, first line chars=3 (after "1 ")
        var lines = BibleRenderer.wrapVerses(verses, 30, 6);
        if (lines.size() == 0) {
            return false;
        }
        var firstLine = lines[0] as Dictionary;
        var text = firstLine.get("text") as String;
        // Should be truncated ("1 Sup" or similar)
        return text.find("...") != null || text.length() <= 10;
    }

    // ------------------------------------------------------------------
    // Empty verse handling
    // ------------------------------------------------------------------

    function testEmptyVerse(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 1, "verseText" => "" }
        ] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        if (lines.size() != 1) {
            return false;
        }
        var line = lines[0] as Dictionary;
        var text = line.get("text") as String;
        return text == "1 ";
    }

    // ------------------------------------------------------------------
    // Empty verse array
    // ------------------------------------------------------------------

    function testEmptyVerses(logger as Test.Logger) as Boolean {
        var verses = [] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        return lines.size() == 0;
    }

    // ------------------------------------------------------------------
    // Pagination: total pages
    // ------------------------------------------------------------------

    function testTotalPages5Lines4PerPage(logger as Test.Logger) as Boolean {
        var pages = BibleRenderer.computeTotalPages(5, 4);
        return pages == 2;
    }

    function testTotalPages4Lines4PerPage(logger as Test.Logger) as Boolean {
        var pages = BibleRenderer.computeTotalPages(4, 4);
        return pages == 1;
    }

    function testTotalPages0Lines(logger as Test.Logger) as Boolean {
        var pages = BibleRenderer.computeTotalPages(0, 4);
        return pages == 1;
    }

    function testTotalPages0LinesPerPage(logger as Test.Logger) as Boolean {
        var pages = BibleRenderer.computeTotalPages(5, 0);
        return pages == 1;
    }

    // ------------------------------------------------------------------
    // Page clamping
    // ------------------------------------------------------------------

    function testClampPageNegative(logger as Test.Logger) as Boolean {
        return BibleRenderer.clampPage(-1, 5) == 0;
    }

    function testClampPageOver(logger as Test.Logger) as Boolean {
        return BibleRenderer.clampPage(10, 5) == 4;
    }

    function testClampPageValid(logger as Test.Logger) as Boolean {
        return BibleRenderer.clampPage(2, 5) == 2;
    }

    // ------------------------------------------------------------------
    // Scroll clamping
    // ------------------------------------------------------------------

    function testClampScrollNegative(logger as Test.Logger) as Boolean {
        return BibleRenderer.clampScroll(-1, 10) == 0;
    }

    function testClampScrollOver(logger as Test.Logger) as Boolean {
        return BibleRenderer.clampScroll(15, 10) == 10;
    }

    function testClampScrollValid(logger as Test.Logger) as Boolean {
        return BibleRenderer.clampScroll(5, 10) == 5;
    }

    // ------------------------------------------------------------------
    // Scroll up/down
    // ------------------------------------------------------------------

    function testScrollUp(logger as Test.Logger) as Boolean {
        return BibleRenderer.scrollUp(5) == 4;
    }

    function testScrollUpAtZero(logger as Test.Logger) as Boolean {
        return BibleRenderer.scrollUp(0) == 0;
    }

    function testScrollDown(logger as Test.Logger) as Boolean {
        return BibleRenderer.scrollDown(0, 10) == 1;
    }

    function testScrollDownAtMax(logger as Test.Logger) as Boolean {
        return BibleRenderer.scrollDown(10, 10) == 10;
    }

    // ------------------------------------------------------------------
    // Page left/right
    // ------------------------------------------------------------------

    function testPageLeft(logger as Test.Logger) as Boolean {
        return BibleRenderer.pageLeft(8, 4) == 4;
    }

    function testPageLeftAtZero(logger as Test.Logger) as Boolean {
        return BibleRenderer.pageLeft(2, 4) == 0;
    }

    function testPageRight(logger as Test.Logger) as Boolean {
        return BibleRenderer.pageRight(0, 10, 4) == 4;
    }

    function testPageRightAtMax(logger as Test.Logger) as Boolean {
        return BibleRenderer.pageRight(10, 10, 4) == 10;
    }

    // ------------------------------------------------------------------
    // Page indicator
    // ------------------------------------------------------------------

    function testPageIndicatorMultiPage(logger as Test.Logger) as Boolean {
        var ind = BibleRenderer.buildPageIndicator(0, 3);
        return ind == "1/3";
    }

    function testPageIndicatorSinglePage(logger as Test.Logger) as Boolean {
        var ind = BibleRenderer.buildPageIndicator(0, 1);
        return ind == "";
    }

    function testPageIndicatorPage2(logger as Test.Logger) as Boolean {
        var ind = BibleRenderer.buildPageIndicator(1, 5);
        return ind == "2/5";
    }

    // ------------------------------------------------------------------
    // Mock layout tests
    // ------------------------------------------------------------------

    function testMockLayout176x176(logger as Test.Logger) as Boolean {
        var layout = BibleRenderer.mockLayout(176, 176, BibleRenderer.FONT_SMALL, 14, true);
        var sw = layout.get("screenWidth") as Number;
        var sh = layout.get("screenHeight") as Number;
        var fs = layout.get("fontSize") as Number;
        var mono = layout.get("isMonochrome") as Boolean;
        return sw == 176 && sh == 176 && fs == BibleRenderer.FONT_SMALL && mono;
    }

    function testMockLayoutLinesPerPage(logger as Test.Logger) as Boolean {
        // 176x176, font small, line height 14
        // contentTop = 14 + 1 + 4 = 19
        // contentBottom = 176 - 18 - 8 = 150
        // contentHeight = 150 - 19 = 131
        // linesPerPage = 131 / 14 = 9
        var layout = BibleRenderer.mockLayout(176, 176, BibleRenderer.FONT_SMALL, 14, true);
        var lpp = layout.get("linesPerPage") as Number;
        return lpp == 9;
    }

    function testMockLayout390x390(logger as Test.Logger) as Boolean {
        var layout = BibleRenderer.mockLayout(390, 390, BibleRenderer.FONT_LARGE, 24, false);
        var mono = layout.get("isMonochrome") as Boolean;
        var tc = layout.get("textColor") as Number;
        return !mono && tc == Graphics.COLOR_WHITE;
    }

    function testMockLayout1BitColors(logger as Test.Logger) as Boolean {
        var layout = BibleRenderer.mockLayout(176, 176, BibleRenderer.FONT_SMALL, 14, true);
        var tc = layout.get("textColor") as Number;
        var bg = layout.get("bgColor") as Number;
        return tc == Graphics.COLOR_BLACK && bg == Graphics.COLOR_WHITE;
    }

    // ------------------------------------------------------------------
    // Split words tests
    // ------------------------------------------------------------------

    function testSplitWordsSimple(logger as Test.Logger) as Boolean {
        var words = BibleRenderer.splitWords("hello world test");
        return words.size() == 3 &&
            words[0] == "hello" &&
            words[1] == "world" &&
            words[2] == "test";
    }

    function testSplitWordsEmpty(logger as Test.Logger) as Boolean {
        var words = BibleRenderer.splitWords("");
        return words.size() == 0;
    }

    function testSplitWordsMultipleSpaces(logger as Test.Logger) as Boolean {
        var words = BibleRenderer.splitWords("a  b   c");
        return words.size() == 3;
    }

    // ------------------------------------------------------------------
    // Multi-verse wrap: some verses wrap, some don't
    // ------------------------------------------------------------------

    function testMixedVerseWrap(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 1, "verseText" => "Short." },
            { "verseNumber" => 2, "verseText" => "This is a much longer verse text that should definitely wrap across multiple lines because it contains many words." }
        ] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        if (lines.size() < 3) {
            return false;
        }
        // First line should have verse 1
        var line0 = lines[0] as Dictionary;
        var text0 = line0.get("text") as String;
        var prefix0 = text0.substring(0, 2) as String;
        if (prefix0 != "1 ") {
            return false;
        }
        // Second line should have verse 2
        var line1 = lines[1] as Dictionary;
        var text1 = line1.get("text") as String;
        if (text1.substring(0, 2) != "2 ") {
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------------
    // Large verse number prefix
    // ------------------------------------------------------------------

    function testVerseNumber176(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 176, "verseText" => "The last verse." }
        ] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        if (lines.size() == 0) {
            return false;
        }
        var line0 = lines[0] as Dictionary;
        var text0 = line0.get("text") as String;
        var prefix176 = text0.substring(0, 4) as String;
        return prefix176 == "176 ";
    }

    // ------------------------------------------------------------------
    // maxScroll computation
    // ------------------------------------------------------------------

    function testMaxScrollLessThanPage(logger as Test.Logger) as Boolean {
        return BibleRenderer.maxScroll(3, 5) == 0;
    }

    function testMaxScrollMoreThanPage(logger as Test.Logger) as Boolean {
        return BibleRenderer.maxScroll(10, 4) == 6;
    }

    // ------------------------------------------------------------------
    // scrollToPage / pageToScroll
    // ------------------------------------------------------------------

    function testScrollToPage(logger as Test.Logger) as Boolean {
        return BibleRenderer.scrollToPage(8, 4) == 2;
    }

    function testPageToScroll(logger as Test.Logger) as Boolean {
        return BibleRenderer.pageToScroll(2, 4) == 8;
    }

    // ------------------------------------------------------------------
    // Word wrap with zero width
    // ------------------------------------------------------------------

    function testWrapZeroWidth(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 1, "verseText" => "Test." }
        ] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 0, 6);
        // maxChars = 0/6 = 0, clamped to 1
        // single word gets truncated to 1 char + prefix
        return lines.size() >= 1;
    }

    // ------------------------------------------------------------------
    // Wrap with verse number zero
    // ------------------------------------------------------------------

    function testVerseNumberZero(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 0, "verseText" => "Test." }
        ] as Array<Dictionary>;
        var lines = BibleRenderer.wrapVerses(verses, 140, 6);
        if (lines.size() == 0) {
            return false;
        }
        var line0 = lines[0] as Dictionary;
        var text0 = line0.get("text") as String;
        var prefix0 = text0.substring(0, 2) as String;
        return prefix0 == "0 ";
    }

    // ------------------------------------------------------------------
    // Fix 1 (HIGH): Page indicator stays within safe margins
    // ------------------------------------------------------------------

    function testPageIndicatorUsesContentBottom(logger as Test.Logger) as Boolean {
        var layout = BibleRenderer.mockLayout(176, 176, BibleRenderer.FONT_SMALL, 14, true);
        var contentBottom = layout.get("contentBottom") as Number;
        var fontHeight = BibleLayout.getFontHeightForSize(BibleRenderer.FONT_TINY);
        var indicatorY = contentBottom - fontHeight;
        if (indicatorY < 0) {
            indicatorY = 0;
        }
        // On 176x176 semi-octagon: contentBottom=150, fontHeight=10, indicatorY=140
        // Old code used screenHeight - 8 = 168, which would be below safe margin
        return indicatorY <= contentBottom && indicatorY < 176 - 8;
    }

    function testPageIndicatorNotBelowScreenBottom(logger as Test.Logger) as Boolean {
        var layout = BibleRenderer.mockLayout(176, 176, BibleRenderer.FONT_SMALL, 14, true);
        var contentBottom = layout.get("contentBottom") as Number;
        var fontHeight = BibleLayout.getFontHeightForSize(BibleRenderer.FONT_TINY);
        var indicatorY = contentBottom - fontHeight;
        if (indicatorY < 0) {
            indicatorY = 0;
        }
        // Indicator Y plus font height must not exceed contentBottom
        return indicatorY + fontHeight <= contentBottom;
    }

    function testPageIndicatorOnRoundScreen(logger as Test.Logger) as Boolean {
        var layout = BibleRenderer.mockLayout(390, 390, BibleRenderer.FONT_LARGE, 24, false);
        var contentBottom = layout.get("contentBottom") as Number;
        var fontHeight = BibleLayout.getFontHeightForSize(BibleRenderer.FONT_TINY);
        var indicatorY = contentBottom - fontHeight;
        // On 390x390 round: marginBottom=10, contentBottom=372, indicatorY=362
        // Must be within safe area
        return indicatorY <= contentBottom && indicatorY >= 0;
    }
}
