using Toybox.Lang;
using Toybox.Math;
using Toybox.Test;

(:test)
function testChordWidthCenterWiderThanEdge(logger as Logger) as Lang.Boolean {
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
function testChordWidthPositiveInsideCircle(logger as Logger) as Lang.Boolean {
    var w = 280;
    var h = 280;
    var cw = RoundLayout.chordWidth(140, w, h);
    Test.assert(cw > 0);
    var left = RoundLayout.chordLeft(140, w, h);
    Test.assert(left >= 0);
    Test.assert(left + cw <= w);
    return true;
}

(:test)
function testChordWidthOutsideReturnsMinimal(logger as Logger) as Lang.Boolean {
    var cw = RoundLayout.chordWidth(-1000, 280, 280);
    Test.assert(cw >= 1);
    return true;
}

(:test)
function testMinChordInBandLeqCenter(logger as Logger) as Lang.Boolean {
    var w = 280;
    var h = 280;
    var minC = RoundLayout.minChordInBand(40, 240, w, h);
    var mid = RoundLayout.chordWidth(140, w, h);
    Test.assert(minC <= mid);
    Test.assert(minC > 0);
    return true;
}

(:test)
function testEdgeMarginFloor(logger as Logger) as Lang.Boolean {
    var m = RoundLayout.edgeMargin(100, 100);
    Test.assert(m >= 6);
    return true;
}

(:test)
function testMaxCenteredColumnWidthFitsBand(logger as Logger) as Lang.Boolean {
    // Enduro 3-ish: column for content band must be <= narrowest chord in that band.
    var w = 280;
    var h = 280;
    var top = 36;
    var bottom = 250;
    var maxW = RoundLayout.maxCenteredColumnWidth(w, h, top, bottom, RoundLayout.CHORD_MARGIN_FRAC);
    Test.assert(maxW > 100);
    Test.assert(maxW < w);
    // Mid chord is wider; max column is driven by the tighter end of the band.
    var r = 140.0;
    var cy = 140.0;
    var dy = top.toFloat() - cy;
    var halfTop = Math.sqrt(r * r - dy * dy) - r * RoundLayout.CHORD_MARGIN_FRAC;
    Test.assert(maxW <= (halfTop * 2.0).toNumber() + 1);
    return true;
}

(:test)
function testColumnRectCenteredAndCapped(logger as Logger) as Lang.Boolean {
    var w = 280;
    var h = 280;
    var top = 40;
    var bottom = 240;
    var col = RoundLayout.columnRect(w, h, top, bottom);
    var left = col[:left] as Lang.Number;
    var cw = col[:width] as Lang.Number;
    Test.assert(cw > 0);
    Test.assert(left >= 0);
    Test.assert(left + cw <= w);
    // Horizontally centered (±1 for integer division).
    var mirror = w - left - cw;
    var diff = left - mirror;
    if (diff < 0) {
        diff = -diff;
    }
    Test.assert(diff <= 1);
    // Must not exceed target frac unless square path (round path caps by safe chord).
    var target = (w * RoundLayout.COLUMN_WIDTH_FRAC).toNumber();
    Test.assert(cw <= target + 1 || cw <= RoundLayout.maxCenteredColumnWidth(w, h, top, bottom, RoundLayout.CHORD_MARGIN_FRAC) + 1);
    return true;
}

(:test)
function testColumnRectTopBottomPreserved(logger as Logger) as Lang.Boolean {
    var col = RoundLayout.columnRect(280, 280, 50, 220);
    Test.assertEqual(col[:top], 50);
    Test.assertEqual(col[:bottom], 220);
    return true;
}

(:test)
function testDefaultReaderLayoutIsRect(logger as Logger) as Lang.Boolean {
    Test.assertEqual(RoundLayout.READER_LAYOUT, RoundLayout.READER_LAYOUT_RECT);
    return true;
}
