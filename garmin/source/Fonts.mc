using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Custom BMFont faces for reader weight hierarchy (SPEC divergences).
//! Full set on Enduro 3 / FR265+ / Venu; low-mem devices alias Light/Medium14 → Regular.
module Fonts {

    // POKE: SHORT_VERSE_CHARS — pull-quote bump when verse text length <= this.
    const SHORT_VERSE_CHARS = 40;

    // POKE: HEADER_TRACK_PX — extra pixels between small-cap header glyphs.
    const HEADER_TRACK_PX = 2;

    // Cache keys for ContentLoader word-width memo (custom fonts are not Lang.Number).
    enum {
        KEY_LIGHT = 1,
        KEY_REGULAR = 2,
        KEY_MEDIUM = 3,
        KEY_MEDIUM_LG = 4,
        KEY_NUM = 5,
        KEY_HEADER = 6
    }

    var _loaded as Lang.Boolean = false;
    var light as Graphics.FontDefinition = Graphics.FONT_XTINY;
    var regular as Graphics.FontDefinition = Graphics.FONT_XTINY;
    var medium as Graphics.FontDefinition = Graphics.FONT_TINY;
    var mediumLg as Graphics.FontDefinition = Graphics.FONT_SMALL;
    var numBold as Graphics.FontDefinition = Graphics.FONT_XTINY;
    var headerCaps as Graphics.FontDefinition = Graphics.FONT_XTINY;

    function ensureLoaded() as Void {
        if (_loaded) {
            return;
        }
        light = WatchUi.loadResource(Rez.Fonts.BodyLight14) as Graphics.FontDefinition;
        regular = WatchUi.loadResource(Rez.Fonts.BodyRegular14) as Graphics.FontDefinition;
        medium = WatchUi.loadResource(Rez.Fonts.BodyMedium14) as Graphics.FontDefinition;
        mediumLg = WatchUi.loadResource(Rez.Fonts.BodyMedium16) as Graphics.FontDefinition;
        numBold = WatchUi.loadResource(Rez.Fonts.NumBold11) as Graphics.FontDefinition;
        headerCaps = WatchUi.loadResource(Rez.Fonts.HeaderCaps11) as Graphics.FontDefinition;
        _loaded = true;
    }

    //! Body face for a verse line: focus / surround / short-verse pull-quote.
    function bodyForVerse(isFocus as Lang.Boolean, verseCharCount as Lang.Number) as Graphics.FontDefinition {
        ensureLoaded();
        // POKE: short-verse uses medium-16 when focused (or always when short — Dylan tune).
        if (verseCharCount > 0 && verseCharCount <= SHORT_VERSE_CHARS) {
            return mediumLg;
        }
        if (isFocus) {
            return regular;
        }
        return light;
    }

    function cacheKeyFor(font as Graphics.FontDefinition) as Lang.Number {
        ensureLoaded();
        if (font == light) {
            return KEY_LIGHT;
        }
        if (font == regular) {
            return KEY_REGULAR;
        }
        if (font == medium) {
            return KEY_MEDIUM;
        }
        if (font == mediumLg) {
            return KEY_MEDIUM_LG;
        }
        if (font == numBold) {
            return KEY_NUM;
        }
        if (font == headerCaps) {
            return KEY_HEADER;
        }
        return KEY_REGULAR;
    }

    //! Draw letterspaced small-caps header (gold). Manual tracking — not bold.
    function drawLetterspacedCaps(dc as Graphics.Dc, cx as Lang.Number, y as Lang.Number,
                                  text as Lang.String, color as Lang.Number) as Void {
        ensureLoaded();
        var caps = text.toUpper();
        var n = caps.length();
        var total = 0;
        var i;
        for (i = 0; i < n; i++) {
            total += dc.getTextWidthInPixels(caps.substring(i, i + 1), headerCaps);
            if (i + 1 < n) {
                total += HEADER_TRACK_PX;
            }
        }
        var x = cx - total / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (i = 0; i < n; i++) {
            var glyph = caps.substring(i, i + 1);
            dc.drawText(x, y, headerCaps, glyph, Graphics.TEXT_JUSTIFY_LEFT);
            x += dc.getTextWidthInPixels(glyph, headerCaps) + HEADER_TRACK_PX;
        }
    }

    //! Width of letterspaced caps (for layout / tests).
    function letterspacedWidth(dc as Graphics.Dc, text as Lang.String) as Lang.Number {
        ensureLoaded();
        var caps = text.toUpper();
        var n = caps.length();
        var total = 0;
        var i;
        for (i = 0; i < n; i++) {
            total += dc.getTextWidthInPixels(caps.substring(i, i + 1), headerCaps);
            if (i + 1 < n) {
                total += HEADER_TRACK_PX;
            }
        }
        return total;
    }
}
