using Toybox.Lang;
using Toybox.Test;

(:test)
function testSnakeIndexRowCol(logger as Logger) as Lang.Boolean {
    var g = new SnakeGrid.Model(21, 5, 4); // John 21 chapters, 5 cols
    Test.assertEqual(g.rowOf(0), 0);
    Test.assertEqual(g.colOf(0), 0);
    Test.assertEqual(g.rowOf(4), 0);
    Test.assertEqual(g.colOf(4), 4);
    Test.assertEqual(g.rowOf(5), 1);
    Test.assertEqual(g.colOf(5), 0);
    Test.assertEqual(g.indexAt(1, 0), 5);
    Test.assertEqual(g.totalRows(), 5);
    return true;
}

(:test)
function testSnakeMidRowWrap(logger as Logger) as Lang.Boolean {
    var g = new SnakeGrid.Model(21, 5, 4);
    g.setFocusIndex(4); // chapter 5
    g.next(); // snake → chapter 6
    Test.assertEqual(g.focusIndex, 5);
    Test.assertEqual(g.focusedChapter(), 6);
    Test.assertEqual(g.rowOf(g.focusIndex), 1);
    Test.assertEqual(g.colOf(g.focusIndex), 0);
    return true;
}

(:test)
function testSnakeWrapEnds(logger as Logger) as Lang.Boolean {
    var g = new SnakeGrid.Model(21, 5, 4);
    g.wrap = true;
    g.setFocusIndex(20);
    g.next();
    Test.assertEqual(g.focusIndex, 0);
    g.prev();
    Test.assertEqual(g.focusIndex, 20);
    return true;
}

(:test)
function testSnakeViewportKeepsFocusRow(logger as Logger) as Lang.Boolean {
    var g = new SnakeGrid.Model(150, 5, 4); // Psalms
    g.setFocusIndex(0);
    Test.assertEqual(g.startRow, 0);
    g.setFocusIndex(25); // row 5
    Test.assert(g.startRow <= g.rowOf(25));
    Test.assert(g.rowOf(25) < g.startRow + g.visibleRows);
    return true;
}

(:test)
function testSnakeRowAccelerator(logger as Logger) as Lang.Boolean {
    var g = new SnakeGrid.Model(21, 5, 4);
    g.setFocusIndex(0);
    g.nextRow();
    Test.assertEqual(g.focusIndex, 5);
    g.prevRow();
    Test.assertEqual(g.focusIndex, 0);
    return true;
}
