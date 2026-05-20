import Toybox.Lang;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Test;

(:test)
class BibleLayoutTest {

    // ------------------------------------------------------------------
    // Font selection: small screens
    // ------------------------------------------------------------------

    function testSelectFontSmall176(logger as Test.Logger) as Boolean {
        return BibleLayout.selectFontSize(176) == BibleLayout.FONT_SMALL;
    }

    function testSelectFontSmall180(logger as Test.Logger) as Boolean {
        return BibleLayout.selectFontSize(180) == BibleLayout.FONT_SMALL;
    }

    function testSelectFontMedium181(logger as Test.Logger) as Boolean {
        return BibleLayout.selectFontSize(181) == BibleLayout.FONT_MEDIUM;
    }

    function testSelectFontMedium218(logger as Test.Logger) as Boolean {
        return BibleLayout.selectFontSize(218) == BibleLayout.FONT_MEDIUM;
    }

    function testSelectFontMedium260(logger as Test.Logger) as Boolean {
        return BibleLayout.selectFontSize(260) == BibleLayout.FONT_MEDIUM;
    }

    function testSelectFontLarge261(logger as Test.Logger) as Boolean {
        return BibleLayout.selectFontSize(261) == BibleLayout.FONT_LARGE;
    }

    function testSelectFontLarge390(logger as Test.Logger) as Boolean {
        return BibleLayout.selectFontSize(390) == BibleLayout.FONT_LARGE;
    }

    function testSelectFontLarge416(logger as Test.Logger) as Boolean {
        return BibleLayout.selectFontSize(416) == BibleLayout.FONT_LARGE;
    }

    // ------------------------------------------------------------------
    // Font heights
    // ------------------------------------------------------------------

    function testFontHeightTiny(logger as Test.Logger) as Boolean {
        return BibleLayout.getFontHeightForSize(BibleLayout.FONT_TINY) == BibleLayout.FONT_HEIGHT_TINY;
    }

    function testFontHeightSmall(logger as Test.Logger) as Boolean {
        return BibleLayout.getFontHeightForSize(BibleLayout.FONT_SMALL) == BibleLayout.FONT_HEIGHT_SMALL;
    }

    function testFontHeightMedium(logger as Test.Logger) as Boolean {
        return BibleLayout.getFontHeightForSize(BibleLayout.FONT_MEDIUM) == BibleLayout.FONT_HEIGHT_MEDIUM;
    }

    function testFontHeightLarge(logger as Test.Logger) as Boolean {
        return BibleLayout.getFontHeightForSize(BibleLayout.FONT_LARGE) == BibleLayout.FONT_HEIGHT_LARGE;
    }

    // ------------------------------------------------------------------
    // Char widths
    // ------------------------------------------------------------------

    function testCharWidthSmall(logger as Test.Logger) as Boolean {
        return BibleLayout.getCharWidthForFontSize(BibleLayout.FONT_SMALL) == BibleLayout.CHAR_WIDTH_SMALL;
    }

    function testCharWidthMedium(logger as Test.Logger) as Boolean {
        return BibleLayout.getCharWidthForFontSize(BibleLayout.FONT_MEDIUM) == BibleLayout.CHAR_WIDTH_MEDIUM;
    }

    function testCharWidthLarge(logger as Test.Logger) as Boolean {
        return BibleLayout.getCharWidthForFontSize(BibleLayout.FONT_LARGE) == BibleLayout.CHAR_WIDTH_LARGE;
    }

    function testCharWidthTiny(logger as Test.Logger) as Boolean {
        return BibleLayout.getCharWidthForFontSize(BibleLayout.FONT_TINY) == BibleLayout.CHAR_WIDTH_TINY;
    }

    // ------------------------------------------------------------------
    // Font from enum
    // ------------------------------------------------------------------

    function testFontFromEnumSmall(logger as Test.Logger) as Boolean {
        return BibleLayout.fontFromEnum(BibleLayout.FONT_SMALL) == Graphics.FONT_SMALL;
    }

    function testFontFromEnumMedium(logger as Test.Logger) as Boolean {
        return BibleLayout.fontFromEnum(BibleLayout.FONT_MEDIUM) == Graphics.FONT_MEDIUM;
    }

    function testFontFromEnumLarge(logger as Test.Logger) as Boolean {
        return BibleLayout.fontFromEnum(BibleLayout.FONT_LARGE) == Graphics.FONT_LARGE;
    }

    function testFontFromEnumTiny(logger as Test.Logger) as Boolean {
        return BibleLayout.fontFromEnum(BibleLayout.FONT_TINY) == Graphics.FONT_TINY;
    }

    // ------------------------------------------------------------------
    // Color schemes
    // ------------------------------------------------------------------

    function testMonoColors(logger as Test.Logger) as Boolean {
        var colors = BibleLayout.getColors(true);
        var tc = colors.get("textColor") as Number;
        var bg = colors.get("bgColor") as Number;
        var hc = colors.get("headerColor") as Number;
        var ac = colors.get("accentColor") as Number;
        var dc = colors.get("dividerColor") as Number;
        var sb = colors.get("selectBg") as Number;
        var st = colors.get("selectText") as Number;
        return tc == Graphics.COLOR_BLACK &&
               bg == Graphics.COLOR_WHITE &&
               hc == Graphics.COLOR_BLACK &&
               ac == Graphics.COLOR_BLACK &&
               dc == Graphics.COLOR_BLACK &&
               sb == Graphics.COLOR_BLACK &&
               st == Graphics.COLOR_WHITE;
    }

    function testColorColors(logger as Test.Logger) as Boolean {
        var colors = BibleLayout.getColors(false);
        var tc = colors.get("textColor") as Number;
        var bg = colors.get("bgColor") as Number;
        var hc = colors.get("headerColor") as Number;
        var ac = colors.get("accentColor") as Number;
        var dc = colors.get("dividerColor") as Number;
        var sb = colors.get("selectBg") as Number;
        var st = colors.get("selectText") as Number;
        return tc == Graphics.COLOR_WHITE &&
               bg == Graphics.COLOR_BLACK &&
               hc == Graphics.COLOR_WHITE &&
               ac == Graphics.COLOR_YELLOW &&
               dc == Graphics.COLOR_WHITE &&
               sb == Graphics.COLOR_WHITE &&
               st == Graphics.COLOR_BLACK;
    }

    // ------------------------------------------------------------------
    // Mock layout: semi-octagon 176x176
    // ------------------------------------------------------------------

    function testMockLayout176SemiOctagon(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var sw = layout.get("screenWidth") as Number;
        var sh = layout.get("screenHeight") as Number;
        var fs = layout.get("fontSize") as Number;
        var mono = layout.get("isMonochrome") as Boolean;
        var mx = layout.get("marginX") as Number;
        var mt = layout.get("marginTop") as Number;
        var mb = layout.get("marginBottom") as Number;
        return sw == 176 && sh == 176 && fs == BibleLayout.FONT_SMALL &&
               mono && mx == 18 && mt == 18 && mb == 18;
    }

    function testMockLayout176ContentWidth(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var cw = layout.get("contentWidth") as Number;
        // 176 - (18 * 2) = 140
        return cw == 140;
    }

    function testMockLayout176ContentHeight(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var ch = layout.get("contentHeight") as Number;
        // contentTop = max(14 + 1 + 4, 18 + 14) = max(19, 32) = 32
        // contentBottom = 176 - 18 - 8 = 150
        // contentHeight = 150 - 32 = 118
        return ch == 118;
    }

    function testMockLayout176LinesPerPage(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var lpp = layout.get("linesPerPage") as Number;
        // 118 / 14 = 8
        return lpp == 8;
    }

    // ------------------------------------------------------------------
    // Mock layout: round 390x390
    // ------------------------------------------------------------------

    function testMockLayout390Round(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var mono = layout.get("isMonochrome") as Boolean;
        var mx = layout.get("marginX") as Number;
        var mt = layout.get("marginTop") as Number;
        var mb = layout.get("marginBottom") as Number;
        return !mono && mx == 10 && mt == 10 && mb == 10;
    }

    function testMockLayout390ContentWidth(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var cw = layout.get("contentWidth") as Number;
        // 390 - (10 * 2) = 370
        return cw == 370;
    }

    function testMockLayout390ContentHeight(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var ch = layout.get("contentHeight") as Number;
        // contentTop = 14 + 1 + 4 = 19
        // contentBottom = 390 - 10 - 8 = 372
        // contentHeight = 372 - 19 = 353
        return ch == 353;
    }

    function testMockLayout390LinesPerPage(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var lpp = layout.get("linesPerPage") as Number;
        // 353 / 24 = 14
        return lpp == 14;
    }

    // ------------------------------------------------------------------
    // Mock layout: rectangle 260x260
    // ------------------------------------------------------------------

    function testMockLayout260Rectangle(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_RECTANGLE);
        var mono = layout.get("isMonochrome") as Boolean;
        var mx = layout.get("marginX") as Number;
        var mt = layout.get("marginTop") as Number;
        var mb = layout.get("marginBottom") as Number;
        return !mono && mx == 4 && mt == 4 && mb == 4;
    }

    function testMockLayout260ContentWidth(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_RECTANGLE);
        var cw = layout.get("contentWidth") as Number;
        // 260 - (4 * 2) = 252
        return cw == 252;
    }

    // ------------------------------------------------------------------
    // Mock layout: round 218x218
    // ------------------------------------------------------------------

    function testMockLayout218Round(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(218, 218, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_ROUND);
        var mx = layout.get("marginX") as Number;
        var cw = layout.get("contentWidth") as Number;
        // margin 10, contentWidth = 218 - 20 = 198
        return mx == 10 && cw == 198;
    }

    // ------------------------------------------------------------------
    // Mock layout: 1-bit color verification
    // ------------------------------------------------------------------

    function testMockLayout1BitTextColor(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var tc = layout.get("textColor") as Number;
        return tc == Graphics.COLOR_BLACK;
    }

    function testMockLayout1BitBgColor(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var bg = layout.get("bgColor") as Number;
        return bg == Graphics.COLOR_WHITE;
    }

    function testMockLayoutColorTextColor(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var tc = layout.get("textColor") as Number;
        return tc == Graphics.COLOR_WHITE;
    }

    function testMockLayoutColorBgColor(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var bg = layout.get("bgColor") as Number;
        return bg == Graphics.COLOR_BLACK;
    }

    function testMockLayoutColorAccent(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var ac = layout.get("accentColor") as Number;
        return ac == Graphics.COLOR_YELLOW;
    }

    // ------------------------------------------------------------------
    // Mock layout: touch screen flag
    // ------------------------------------------------------------------

    function testMockLayoutTouchFlag(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var touch = layout.get("hasTouchScreen") as Boolean;
        return touch == false;
    }

    // ------------------------------------------------------------------
    // Mock layout: char width
    // ------------------------------------------------------------------

    function testMockLayoutCharWidthSmall(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var cw = layout.get("charWidth") as Number;
        return cw == BibleLayout.CHAR_WIDTH_SMALL;
    }

    function testMockLayoutCharWidthLarge(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var cw = layout.get("charWidth") as Number;
        return cw == BibleLayout.CHAR_WIDTH_LARGE;
    }

    // ------------------------------------------------------------------
    // Safe area: verify no text drawn outside safe area
    //   For any layout, content area must be within safe margins
    // ------------------------------------------------------------------

    function testSafeAreaSemiOctagon(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var mx = layout.get("marginX") as Number;
        var mt = layout.get("marginTop") as Number;
        var mb = layout.get("marginBottom") as Number;
        var sw = layout.get("screenWidth") as Number;
        var sh = layout.get("screenHeight") as Number;
        var ct = layout.get("contentTop") as Number;
        var cb = layout.get("contentBottom") as Number;
        // contentTop must be >= marginTop
        // contentBottom must be <= screenHeight - marginBottom
        return ct >= mt && cb <= (sh - mb) && mx >= 0;
    }

    function testSafeAreaRound(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_ROUND);
        var mx = layout.get("marginX") as Number;
        var mt = layout.get("marginTop") as Number;
        var mb = layout.get("marginBottom") as Number;
        var sw = layout.get("screenWidth") as Number;
        var sh = layout.get("screenHeight") as Number;
        var ct = layout.get("contentTop") as Number;
        var cb = layout.get("contentBottom") as Number;
        return ct >= mt && cb <= (sh - mb) && mx == 10;
    }

    function testSafeAreaRectangle(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_RECTANGLE);
        var mx = layout.get("marginX") as Number;
        var mt = layout.get("marginTop") as Number;
        var mb = layout.get("marginBottom") as Number;
        var sw = layout.get("screenWidth") as Number;
        var sh = layout.get("screenHeight") as Number;
        var ct = layout.get("contentTop") as Number;
        var cb = layout.get("contentBottom") as Number;
        return ct >= mt && cb <= (sh - mb) && mx == 4;
    }

    // ------------------------------------------------------------------
    // Edge case: very small screen
    // ------------------------------------------------------------------

    function testVerySmallScreen(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(100, 100, BibleLayout.FONT_TINY, 10, true, System.SCREEN_SHAPE_RECTANGLE);
        var lpp = layout.get("linesPerPage") as Number;
        // Even tiny screens must have at least 1 line per page
        return lpp >= 1;
    }

    // ------------------------------------------------------------------
    // Edge case: content width positive
    // ------------------------------------------------------------------

    function testContentWidthPositive(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var cw = layout.get("contentWidth") as Number;
        return cw > 0;
    }

    // ------------------------------------------------------------------
    // Edge case: content height positive
    // ------------------------------------------------------------------

    function testContentHeightPositive(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var ch = layout.get("contentHeight") as Number;
        return ch > 0;
    }

    // ------------------------------------------------------------------
    // Target device configurations (all 9 manifest devices)
    // ------------------------------------------------------------------

    function testInstinct3Solar(logger as Test.Logger) as Boolean {
        // 176x176 semi-octagon, 1-bit
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var mono = layout.get("isMonochrome") as Boolean;
        var mx = layout.get("marginX") as Number;
        var fs = layout.get("fontSize") as Number;
        return mono && mx == 18 && fs == BibleLayout.FONT_SMALL;
    }

    function testInstinct3Amoled(logger as Test.Logger) as Boolean {
        // 176x176 semi-octagon, color
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, false, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var mono = layout.get("isMonochrome") as Boolean;
        var tc = layout.get("textColor") as Number;
        return !mono && tc == Graphics.COLOR_WHITE;
    }

    function testFenix7(logger as Test.Logger) as Boolean {
        // 260x260 round, color
        var layout = BibleLayout.mockLayout(260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_ROUND);
        var mono = layout.get("isMonochrome") as Boolean;
        var mx = layout.get("marginX") as Number;
        var fs = layout.get("fontSize") as Number;
        return !mono && mx == 10 && fs == BibleLayout.FONT_MEDIUM;
    }

    function testVenu3(logger as Test.Logger) as Boolean {
        // 390x390 round, color, touch
        var layout = BibleLayout.mockLayout(390, 390, BibleLayout.FONT_LARGE, 24, false, System.SCREEN_SHAPE_ROUND);
        var mono = layout.get("isMonochrome") as Boolean;
        var mx = layout.get("marginX") as Number;
        var fs = layout.get("fontSize") as Number;
        return !mono && mx == 10 && fs == BibleLayout.FONT_LARGE;
    }

    function testDescentG2(logger as Test.Logger) as Boolean {
        // 176x176 semi-octagon, 1-bit
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var mono = layout.get("isMonochrome") as Boolean;
        var mx = layout.get("marginX") as Number;
        return mono && mx == 18;
    }

    function testD2Mach1(logger as Test.Logger) as Boolean {
        // 260x260 round, color
        var layout = BibleLayout.mockLayout(260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_ROUND);
        var mono = layout.get("isMonochrome") as Boolean;
        var mx = layout.get("marginX") as Number;
        return !mono && mx == 10;
    }

    function testApproachS50(logger as Test.Logger) as Boolean {
        // 260x260 round, color
        var layout = BibleLayout.mockLayout(260, 260, BibleLayout.FONT_MEDIUM, 18, false, System.SCREEN_SHAPE_ROUND);
        var mono = layout.get("isMonochrome") as Boolean;
        var mx = layout.get("marginX") as Number;
        return !mono && mx == 10;
    }

    function testInstinctE40(logger as Test.Logger) as Boolean {
        // 176x176 semi-octagon, 1-bit
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var mono = layout.get("isMonochrome") as Boolean;
        var mx = layout.get("marginX") as Number;
        return mono && mx == 18;
    }

    function testInstinctE45(logger as Test.Logger) as Boolean {
        // 176x176 semi-octagon, 1-bit
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var mono = layout.get("isMonochrome") as Boolean;
        var mx = layout.get("marginX") as Number;
        return mono && mx == 18;
    }

    // ------------------------------------------------------------------
    // Consistency: selectFontSize + getCharWidthForFontSize round-trip
    // ------------------------------------------------------------------

    function testFontCharWidthConsistency176(logger as Test.Logger) as Boolean {
        var fs = BibleLayout.selectFontSize(176);
        var cw = BibleLayout.getCharWidthForFontSize(fs);
        return cw == BibleLayout.CHAR_WIDTH_SMALL;
    }

    function testFontCharWidthConsistency260(logger as Test.Logger) as Boolean {
        var fs = BibleLayout.selectFontSize(260);
        var cw = BibleLayout.getCharWidthForFontSize(fs);
        return cw == BibleLayout.CHAR_WIDTH_MEDIUM;
    }

    function testFontCharWidthConsistency390(logger as Test.Logger) as Boolean {
        var fs = BibleLayout.selectFontSize(390);
        var cw = BibleLayout.getCharWidthForFontSize(fs);
        return cw == BibleLayout.CHAR_WIDTH_LARGE;
    }
}
