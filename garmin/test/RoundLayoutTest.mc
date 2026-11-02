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
function testInscribedColumnEnduro3AtLeast72Percent(logger as Logger) as Lang.Boolean {
    // Enduro 3 280×280, reading band ~0.22H..0.86H — must be >= 72% width (Dylan review of b288b7f).
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
function testInscribedColumnFormulaUsesRadiusNotDiameter(logger as Logger) as Lang.Boolean {
    // Sanity: for a centered band with hLimit=70 on r=140, width ≈ 2*sqrt(140^2-70^2) - 2*pad.
    var r = 140.0;
    var hLimit = 70.0;
    var expected = 2.0 * (Math.sqrt(r * r - hLimit * hLimit) - RoundLayout.COLUMN_PIXEL_PAD);
    var colW = RoundLayout.inscribedColumnWidth(280, 280, 140 - 70, 140 + 70);
    // Pull-in / soft-cap may change it, but should be in the neighborhood of the geometric width.
    Test.assert(colW > 200);
    Test.assert(colW < 240);
    Test.assert(expected > 200.0);
    return true;
}

(:test)
function testColumnRectPreservesCenteredLeft(logger as Logger) as Lang.Boolean {
    var w = 280;
    var h = 280;
    var top = (h * RoundLayout.COLUMN_BAND_TOP_FRAC).toNumber();
    var bot = (h * RoundLayout.COLUMN_BAND_BOTTOM_FRAC).toNumber();
    var col = RoundLayout.columnRect(w, h, top, bot);
    var left = col[:left] as Lang.Number;
    var cw = col[:width] as Lang.Number;
    var mirror = w - left - cw;
    var diff = left - mirror;
    if (diff < 0) {
        diff = -diff;
    }
    Test.assert(diff <= 1);
    Test.assert(cw >= (w * 0.72).toNumber());
    return true;
}

(:test)
function testDefaultReaderLayoutIsRect(logger as Logger) as Lang.Boolean {
    Test.assertEqual(RoundLayout.READER_LAYOUT, RoundLayout.READER_LAYOUT_RECT);
    return true;
}

(:test)
function testEdgeMarginFloor(logger as Logger) as Lang.Boolean {
    var m = RoundLayout.edgeMargin(100, 100);
    Test.assert(m >= 6);
    return true;
}
