using Toybox.Lang;
using Toybox.Test;

function _line(kind as Lang.Number, book as Lang.Number, chapter as Lang.Number, verse as Lang.Number, start as Lang.Boolean) as ScrollModel.Line {
    return new ScrollModel.Line(kind, book, chapter, verse, "x", start);
}

(:test)
function testSnapToVerseStart(logger as Test.Logger) as Lang.Boolean {
    var lines = [
        _line(ScrollModel.KIND_VERSE, 42, 3, 1, true),
        _line(ScrollModel.KIND_VERSE, 42, 3, 1, false),
        _line(ScrollModel.KIND_VERSE, 42, 3, 1, false),
        _line(ScrollModel.KIND_VERSE, 42, 3, 2, true),
        _line(ScrollModel.KIND_VERSE, 42, 3, 2, false)
    ];
    Test.assertEqual(ScrollModel.snapToVerseStart(lines, 2), 0);
    Test.assertEqual(ScrollModel.snapToVerseStart(lines, 4), 3);
    return true;
}

(:test)
function testFocusVerseIncrementalMidVerse(logger as Test.Logger) as Lang.Boolean {
    var lines = [
        _line(ScrollModel.KIND_VERSE, 42, 3, 1, true),
        _line(ScrollModel.KIND_VERSE, 42, 3, 1, false),
        _line(ScrollModel.KIND_VERSE, 42, 3, 1, false),
        _line(ScrollModel.KIND_VERSE, 42, 3, 2, true)
    ];
    var f = ScrollModel.lineOffsetToFocusVerse(lines, 2);
    Test.assertEqual(f[:book], 42);
    Test.assertEqual(f[:chapter], 3);
    Test.assertEqual(f[:verse], 1);
    return true;
}

(:test)
function testFocusVerseOnDividerAttachesToNext(logger as Test.Logger) as Lang.Boolean {
    var lines = [
        _line(ScrollModel.KIND_VERSE, 42, 3, 36, true),
        _line(ScrollModel.KIND_DIVIDER, 42, 4, 0, false),
        _line(ScrollModel.KIND_VERSE, 42, 4, 1, true)
    ];
    var f = ScrollModel.lineOffsetToFocusVerse(lines, 1);
    Test.assertEqual(f[:book], 42);
    Test.assertEqual(f[:chapter], 4);
    Test.assertEqual(f[:verse], 1);
    return true;
}

(:test)
function testVerseModeCrossesBoundaryInOneStep(logger as Test.Logger) as Lang.Boolean {
    var s = new ScrollModel.State();
    s.mode = ScrollModel.MODE_VERSE;
    s.visibleCount = 4;
    s.lines = [
        _line(ScrollModel.KIND_VERSE, 42, 3, 36, true),
        _line(ScrollModel.KIND_DIVIDER, 42, 4, 0, false),
        _line(ScrollModel.KIND_VERSE, 42, 4, 1, true),
        _line(ScrollModel.KIND_VERSE, 42, 4, 1, false)
    ];
    s.scrollOffset = 0;
    s.next(); // one verse action → land on divider (attached to v1)
    Test.assertEqual(s.scrollOffset, 1);
    var f = s.focusVerse();
    Test.assertEqual(f[:chapter], 4);
    Test.assertEqual(f[:verse], 1);
    return true;
}

(:test)
function testIncrementalStepsThroughDivider(logger as Test.Logger) as Lang.Boolean {
    var s = new ScrollModel.State();
    s.mode = ScrollModel.MODE_INCREMENTAL;
    s.visibleCount = 2;
    s.lines = [
        _line(ScrollModel.KIND_VERSE, 42, 3, 36, true),
        _line(ScrollModel.KIND_DIVIDER, 42, 4, 0, false),
        _line(ScrollModel.KIND_VERSE, 42, 4, 1, true)
    ];
    s.scrollOffset = 0;
    s.next();
    Test.assertEqual(s.scrollOffset, 1); // now on divider alone as top line
    s.next();
    Test.assertEqual(s.scrollOffset, 1); // clamped maxScroll = 3-2 = 1
    return true;
}

(:test)
function testTallVerseStepsInsideBeforeCrossing(logger as Test.Logger) as Lang.Boolean {
    var s = new ScrollModel.State();
    s.mode = ScrollModel.MODE_VERSE;
    s.visibleCount = 2;
    s.lines = [
        _line(ScrollModel.KIND_VERSE, 42, 3, 16, true),
        _line(ScrollModel.KIND_VERSE, 42, 3, 16, false),
        _line(ScrollModel.KIND_VERSE, 42, 3, 16, false),
        _line(ScrollModel.KIND_VERSE, 42, 3, 17, true)
    ];
    s.scrollOffset = 0;
    // v3 SCROLL_STEP: a verse taller than the band pages (visibleCount - 1) inside itself,
    // then the next press snaps to the next verse start once its tail is on screen.
    s.next();
    Test.assertEqual(s.scrollOffset, 1);
    s.next();
    Test.assertEqual(s.scrollOffset, 3);
    return true;
}

(:test)
function testVerseStepMovesWholeVerse(logger as Test.Logger) as Lang.Boolean {
    var s = new ScrollModel.State();
    s.mode = ScrollModel.MODE_VERSE;
    s.visibleCount = 6;
    s.lines = [
        _line(ScrollModel.KIND_VERSE, 42, 14, 2, true),
        _line(ScrollModel.KIND_VERSE, 42, 14, 2, false),
        _line(ScrollModel.KIND_VERSE, 42, 14, 2, false),
        _line(ScrollModel.KIND_VERSE, 42, 14, 2, false),
        _line(ScrollModel.KIND_VERSE, 42, 14, 3, true),
        _line(ScrollModel.KIND_VERSE, 42, 14, 3, false)
    ];
    s.scrollOffset = 0;
    s.next(); // one press = 4 lines (whole verse 2)
    Test.assertEqual(s.scrollOffset, 4);
    s.prev();
    Test.assertEqual(s.scrollOffset, 0);
    return true;
}

(:test)
function testDividerNeverTopLine(logger as Test.Logger) as Lang.Boolean {
    // Mal 4:6 -> Mat 1:1 buffer shape: verse, spacer, divider, spacer, verse.
    var s = new ScrollModel.State();
    s.visibleCount = 3;
    s.lines = [
        _line(ScrollModel.KIND_VERSE, 38, 4, 6, true),
        _line(ScrollModel.KIND_SPACER, 39, 1, 0, false),
        _line(ScrollModel.KIND_DIVIDER, 39, 1, 0, false),
        _line(ScrollModel.KIND_SPACER, 39, 1, 0, false),
        _line(ScrollModel.KIND_VERSE, 39, 1, 1, true),
        _line(ScrollModel.KIND_VERSE, 39, 1, 1, false),
        _line(ScrollModel.KIND_VERSE, 39, 1, 2, true)
    ];
    s.mode = ScrollModel.MODE_INCREMENTAL;
    s.scrollOffset = 0;
    s.next();
    Test.assertEqual(s.scrollOffset, 1); // spacer above divider = padded
    s.next();
    Test.assertEqual(s.scrollOffset, 3); // skipped the divider line
    s.prev();
    Test.assertEqual(s.scrollOffset, 1);
    s.mode = ScrollModel.MODE_VERSE;
    s.scrollOffset = 0;
    s.next();
    Test.assertEqual(s.scrollOffset, 1); // boundary stop = spacer above divider
    s.next();
    Test.assertEqual(s.scrollOffset, 4); // Mat 1:1
    s.prev();
    Test.assertEqual(s.scrollOffset, 1);
    s.prev();
    Test.assertEqual(s.scrollOffset, 0);
    return true;
}
