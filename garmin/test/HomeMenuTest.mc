using Toybox.Lang;
using Toybox.Test;

//! v6: the app menu is reachable from the books screen (last row + MENU), and it lists
//! Bookmarks, Settings and About (Continue only once something was read).
(:test)
function testHomeListEndsWithMenuRow(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(HOME_ROWS, Books.BOOK_COUNT + 1);
    Test.assertEqual(HOME_MENU_ROW, Books.BOOK_COUNT);
    // Up from Genesis wraps straight onto the menu row.
    Test.assertEqual((0 + HOME_ROWS - 1) % HOME_ROWS, HOME_MENU_ROW);
    Test.assert(PickList.MENU_ROW_SHORT.length() <= 4);
    return true;
}

(:test)
function testHomeMenuItems(logger as Test.Logger) as Lang.Boolean {
    var saved = LastReadApp.pending;
    LastReadApp.pending = null;
    var ids = [] as Lang.Array;
    var items = HomeMenu2Delegate.items();
    var i;
    for (i = 0; i < items.size(); i++) {
        ids.add((items[i] as Lang.Array)[2]);
    }
    Test.assert(ids.indexOf(:bookmarks) >= 0);
    Test.assert(ids.indexOf(:settings) >= 0);
    Test.assert(ids.indexOf(:about) >= 0);
    Test.assert(ids.indexOf(:settings) > ids.indexOf(:bookmarks));
    // Continue appears (first) once there is a last-read position.
    LastReadApp.pending = [42, 3, 16];
    var withResume = HomeMenu2Delegate.items();
    Test.assertEqual((withResume[0] as Lang.Array)[2], :resume);
    Test.assert(((withResume[0] as Lang.Array)[1] as Lang.String).equals(Books.refLabel(42, 3, 16)));
    LastReadApp.pending = saved;
    return true;
}

//! A prepared reader is only reused for the same resume target.
(:test)
function testReaderTargetFor(logger as Test.Logger) as Lang.Boolean {
    var sp = LastReadApp.pending;
    var sv = LastReadApp.resumeVerse;
    LastReadApp.pending = [42, 3, 16];
    LastReadApp.resumeVerse = 16;
    Test.assertEqual(ReaderView.targetFor(42, 3), 16);
    Test.assertEqual(ReaderView.targetFor(42, 4), 0);
    LastReadApp.resumeVerse = 0;
    Test.assertEqual(ReaderView.targetFor(42, 3), 0);
    LastReadApp.pending = sp;
    LastReadApp.resumeVerse = sv;
    return true;
}
