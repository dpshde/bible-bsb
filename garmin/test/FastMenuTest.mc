using Toybox.Lang;
using Toybox.Test;

//! 0.9.6: FastMenu keeps the Menu2 calls the app uses (find by id, focus) and steps like the
//! CustomMenu it replaces (wrap at both ends); a tap maps to the row under it.
(:test)
function testFastMenuFindAndFocus(logger as Test.Logger) as Lang.Boolean {
    var m = new FastMenu("T", 50, false);
    m.addItem(new P1MenuItem("A", null, :a));
    m.addItem(new P1MenuItem("B", "sub", 7));
    m.addItem(new P1MenuItem("C", null, -2));
    Test.assertEqual(m.size(), 3);
    Test.assertEqual(m.findItemById(:a), 0);
    Test.assertEqual(m.findItemById(7), 1);
    Test.assertEqual(m.findItemById(-2), 2);
    Test.assertEqual(m.findItemById(:nope), -1);
    Test.assertEqual(m.findItemById(null), -1);
    m.setFocus(9);
    Test.assertEqual(m.getFocus(), 2);
    Test.assertEqual(UiMenu.lastFocusId, -2);
    m.setFocus(-1);
    Test.assertEqual(m.getFocus(), 0);
    return true;
}

(:test)
function testFastMenuStepWrapsAndTapRow(logger as Test.Logger) as Lang.Boolean {
    var m = new FastMenu("T", 50, false);
    for (var i = 0; i < 4; i++) {
        m.addItem(new P1MenuItem("R" + i, null, i));
    }
    m.step(-1);
    Test.assertEqual(m.getFocus(), FastMenuPoke.WRAP ? 3 : 0);
    m.setFocus(3);
    m.step(1);
    Test.assertEqual(m.getFocus(), FastMenuPoke.WRAP ? 0 : 3);
    m.lastTop = 100;
    Test.assertEqual(m.rowAt(99), -1);  // title
    Test.assertEqual(m.rowAt(100), 0);
    Test.assertEqual(m.rowAt(249), 2);
    Test.assertEqual(m.rowAt(300), -1); // past the last row
    return true;
}

//! 0.9.7: committed builds carry no personal sync key (the stub); a drag never wraps the list.
(:test)
function testPersonalStubAndDragNoWrap(logger as Test.Logger) as Lang.Boolean {
    Test.assert(PersonalSync.key() == null);
    var m = new FastMenu("T", 50, false);
    m.addItem(new P1MenuItem("A", null, 0));
    m.addItem(new P1MenuItem("B", null, 1));
    m.stepWrap(-1, false);
    Test.assertEqual(m.getFocus(), 0);
    m.stepWrap(1, false);
    m.stepWrap(1, false);
    Test.assertEqual(m.getFocus(), 1);
    return true;
}
