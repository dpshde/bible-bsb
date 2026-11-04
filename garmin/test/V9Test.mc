using Toybox.Application;
using Toybox.Lang;
using Toybox.Test;

//! v9: range bookmarks (book/chapter/startVerse/endVerse) and migration of pre-v9 bookmarks.

function v9Reset() as Void {
    Application.Storage.deleteValue(Bookmarks.STORAGE_KEY);
    Bookmarks._cache = null;
}

(:test)
function testRangePackUnpack(logger as Test.Logger) as Lang.Boolean {
    var id = Bookmarks.packRange(0, 1, 1, 3);
    Test.assertEqual(Bookmarks.unpackBook(id), 0);
    Test.assertEqual(Bookmarks.unpackChapter(id), 1);
    Test.assertEqual(Bookmarks.unpackVerse(id), 1);
    Test.assertEqual(Bookmarks.unpackEnd(id), 3);
    Test.assert(Bookmarks.isRange(id));
    // End verse >= 128 sets the sign bit; it must still round-trip (Psalm 119:150–176).
    var ps = Bookmarks.packRange(18, 119, 150, 176);
    Test.assertEqual(Bookmarks.unpackBook(ps), 18);
    Test.assertEqual(Bookmarks.unpackChapter(ps), 119);
    Test.assertEqual(Bookmarks.unpackVerse(ps), 150);
    Test.assertEqual(Bookmarks.unpackEnd(ps), 176);
    // A one-verse "range" is the same id as a v8 single-verse bookmark.
    Test.assertEqual(Bookmarks.packRange(42, 3, 16, 16), Bookmarks.pack(42, 3, 16));
    return true;
}

(:test)
function testRangeLabelEnDash(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(Bookmarks.formatLabel(Bookmarks.packRange(0, 1, 1, 3)), "Genesis 1:1–3");
    Test.assertEqual(Bookmarks.formatLabel(Bookmarks.packRange(42, 3, 16, 16)), "John 3:16");
    Test.assertEqual(Bookmarks.formatLabel(Bookmarks.pack(18, 119, 0)), "Psalms 119");
    return true;
}

(:test)
function testMigrateV8Bookmarks(logger as Test.Logger) as Lang.Boolean {
    v9Reset();
    // Exactly what v8 wrote: packed single-verse and chapter ids.
    var v8 = [Bookmarks.pack(42, 3, 16), Bookmarks.pack(0, 1, 0), Bookmarks.pack(18, 23, 1)];
    Application.Storage.setValue(Bookmarks.STORAGE_KEY, v8);
    var list = Bookmarks.load();
    Test.assertEqual(list.size(), 3);
    var i;
    for (i = 0; i < 3; i++) {
        var id = list[i] as Lang.Number;
        Test.assertEqual(id, v8[i]);
        Test.assertEqual(Bookmarks.unpackEnd(id), Bookmarks.unpackVerse(id)); // endVerse = startVerse
        Test.assert(!Bookmarks.isRange(id));
    }
    Test.assertEqual(Bookmarks.formatLabel(list[0] as Lang.Number), "John 3:16");
    // Old single-verse toggle still removes the migrated bookmark.
    Test.assertEqual(Bookmarks.toggle(42, 3, 16), :removed);
    Test.assertEqual(Bookmarks.load().size(), 2);
    v9Reset();
    return true;
}

(:test)
function testAddRangeExistsRemove(logger as Test.Logger) as Lang.Boolean {
    v9Reset();
    Test.assertEqual(Bookmarks.addRange(0, 1, 1, 3), :added);
    Test.assertEqual(Bookmarks.addRange(0, 1, 1, 3), :exists);
    Test.assertEqual(Bookmarks.addRange(0, 1, 3, 1), :exists);  // reversed pick normalizes
    Test.assertEqual(Bookmarks.addRange(0, 1, 1, 1), :added);   // the single verse is separate
    Test.assertEqual(Bookmarks.load().size(), 2);
    Test.assertEqual(Bookmarks.load()[0], Bookmarks.pack(0, 1, 1)); // newest first
    Bookmarks._cache = null;                                      // survives a reload
    Test.assertEqual(Bookmarks.load().size(), 2);
    Bookmarks.remove(Bookmarks.packRange(0, 1, 1, 3));
    Test.assertEqual(Bookmarks.load().size(), 1);
    Test.assert(!Bookmarks.isRange(Bookmarks.load()[0] as Lang.Number));
    v9Reset();
    return true;
}

(:test)
function testLoadDropsBadEndByte(logger as Test.Logger) as Lang.Boolean {
    v9Reset();
    // An end byte below the start verse is never written; it reads back as the single verse.
    var bad = Bookmarks.pack(0, 1, 5) | (2 << 24);
    Application.Storage.setValue(Bookmarks.STORAGE_KEY, [bad]);
    var list = Bookmarks.load();
    Test.assertEqual(list.size(), 1);
    Test.assertEqual(list[0], Bookmarks.pack(0, 1, 5));
    v9Reset();
    return true;
}
