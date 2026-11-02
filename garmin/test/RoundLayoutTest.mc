using Toybox.Lang;
using Toybox.Math;
using Toybox.Test;

(:test)
function testChordWidthCenterWiderThanEdge(logger as Test.Logger) as Lang.Boolean {
    var r = 140.0;
    var cy = 140.0;
    var margin = r * RoundLayout.CHORD_MARGIN_FRAC;
    var dyTop = 40.0 - cy;
    var dyMid = 140.0 - cy;
    var halfTop = Math.sqrt(r * r - dyTop * dyTop) - margin;
    var halfMid = Math.sqrt(r * r - dyMid * dyMid) - margin;
    Test.assert(halfMid > halfTop);
    Test.assert(halfTop > 0);
    return true;
}

(:test)
function testLensBandWidthAtLeast75PercentOn280(logger as Test.Logger) as Lang.Boolean {
    // Enduro 3 280×280 — center-band column must be >= 0.75 D (Dylan).
    var w = 280;
    var h = 280;
    var lens = RoundLayout.lensBandEx(w, h, true);
    var colW = lens[:width] as Lang.Number;
    var floorW = (w * RoundLayout.COLUMN_WIDTH_MIN_FRAC).toNumber();
    Test.assert(colW >= floorW);
    Test.assert(colW >= (w * 0.75).toNumber());
    Test.assert(colW <= w);
    return true;
}

(:test)
function testLensBandTextStaysInsideBand(logger as Test.Logger) as Lang.Boolean {
    // Content y range must sit inside [bandTop, bandBottom]; arcs hold meta/preview only.
    var w = 280;
    var h = 280;
    var lens = RoundLayout.lensBandEx(w, h, true);
    var bandTop = lens[:bandTop] as Lang.Number;
    var bandBottom = lens[:bandBottom] as Lang.Number;
    var metaBottom = lens[:metaBottom] as Lang.Number;
    var previewTop = lens[:previewTop] as Lang.Number;
    Test.assert(metaBottom <= bandTop);
    Test.assert(bandBottom <= previewTop);
    Test.assert(bandTop >= (h * 0.18).toNumber() - 1);
    Test.assert(bandBottom <= (h * 0.82).toNumber() + 1);
    // Four body lines of ~12px must fit inside the band (clip contract).
    var lineH = 12;
    var y = bandTop;
    var i;
    for (i = 0; i < 4; i++) {
        Test.assert(RoundLayout.isInsideBand(y, lineH, bandTop, bandBottom));
        y += lineH;
    }
    // A line that starts at bandBottom is outside.
    Test.assert(!RoundLayout.isInsideBand(bandBottom, lineH, bandTop, bandBottom));
    return true;
}

(:test)
function testLensColumnWidthMatchesMinChord(logger as Test.Logger) as Lang.Boolean {
    var w = 280;
    var h = 280;
    var top = (h * RoundLayout.LENS_BAND_TOP_FRAC).toNumber();
    var bot = (h * RoundLayout.LENS_BAND_BOTTOM_FRAC).toNumber();
    var colW = RoundLayout.lensColumnWidth(w, h, top, bot);
    var wTop = RoundLayout.rawChordWidth(top, w, h);
    var wBot = RoundLayout.rawChordWidth(bot, w, h);
    var minChord = wTop < wBot ? wTop : wBot;
    var floorW = (w * RoundLayout.COLUMN_WIDTH_MIN_FRAC).toNumber();
    var expected = minChord < floorW ? floorW : minChord;
    Test.assertEqual(colW, expected);
    return true;
}

(:test)
function testInscribedColumnEnduro3AtLeast72Percent(logger as Test.Logger) as Lang.Boolean {
    var w = 280;
    var h = 280;
    var top = (h * RoundLayout.COLUMN_BAND_TOP_FRAC).toNumber();
    var bot = (h * RoundLayout.COLUMN_BAND_BOTTOM_FRAC).toNumber();
    var colW = RoundLayout.inscribedColumnWidth(w, h, top, bot);
    var floorW = (w * RoundLayout.COLUMN_WIDTH_MIN_FRAC).toNumber();
    Test.assert(colW >= floorW);
    Test.assert(colW >= (w * 0.72).toNumber());
    Test.assert(colW <= w);
    return true;
}

(:test)
function testDefaultReaderLayoutIsLens(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(RoundLayout.READER_LAYOUT, RoundLayout.READER_LAYOUT_LENS);
    return true;
}

(:test)
function testEdgeMarginFloor(logger as Test.Logger) as Lang.Boolean {
    var m = RoundLayout.edgeMargin(100, 100);
    Test.assert(m >= 6);
    return true;
}

(:test)
function testVerseGapFracInTuneRange(logger as Test.Logger) as Lang.Boolean {
    // POKE: VERSE_GAP_FRAC — Dylan range 0.4–0.5.
    Test.assert(RoundLayout.VERSE_GAP_FRAC >= 0.4);
    Test.assert(RoundLayout.VERSE_GAP_FRAC <= 0.5);
    return true;
}
