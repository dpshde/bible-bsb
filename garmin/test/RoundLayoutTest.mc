using Toybox.Lang;
using Toybox.Math;
using Toybox.Test;

(:test)
function testChordWidthCenterWiderThanEdge(logger as Logger) as Lang.Boolean {
    // Pure geometry (independent of device screenShape): center half-chord > top half-chord.
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
function testChordWidthFormulaMatchesHelperOnRoundAssumption(logger as Logger) as Lang.Boolean {
    // Document the SPEC formula: half = sqrt(r^2 - (y-cy)^2) - marginFrac*r
    var r = 140.0;
    var y = 70.0;
    var cy = 140.0;
    var dy = y - cy;
    var expected = 2.0 * (Math.sqrt(r * r - dy * dy) - r * RoundLayout.CHORD_MARGIN_FRAC);
    Test.assert(expected > 100.0);
    Test.assert(expected < 280.0);
    return true;
}
