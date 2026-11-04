using Toybox.Lang;
using Toybox.Test;

(:test)
function testBookmarkPackUnpack(logger as Test.Logger) as Lang.Boolean {
    var id = Bookmarks.pack(42, 3, 16);
    Test.assertEqual(Bookmarks.unpackBook(id), 42);
    Test.assertEqual(Bookmarks.unpackChapter(id), 3);
    Test.assertEqual(Bookmarks.unpackVerse(id), 16);
    return true;
}

(:test)
function testBookmarkChapterLevelVerseZero(logger as Test.Logger) as Lang.Boolean {
    var id = Bookmarks.pack(18, 119, 0);
    Test.assertEqual(Bookmarks.unpackBook(id), 18);
    Test.assertEqual(Bookmarks.unpackChapter(id), 119);
    Test.assertEqual(Bookmarks.unpackVerse(id), 0);
    return true;
}

(:test)
function testBookmarkPackEdges(logger as Test.Logger) as Lang.Boolean {
    var gen = Bookmarks.pack(0, 1, 1);
    Test.assertEqual(Bookmarks.unpackBook(gen), 0);
    var rev = Bookmarks.pack(65, 22, 21);
    Test.assertEqual(Bookmarks.unpackBook(rev), 65);
    Test.assertEqual(Bookmarks.unpackChapter(rev), 22);
    Test.assertEqual(Bookmarks.unpackVerse(rev), 21);
    return true;
}

(:test)
function testBookmarkFormatLabel(logger as Test.Logger) as Lang.Boolean {
    var verse = Bookmarks.pack(42, 3, 16);
    Test.assertEqual(Bookmarks.formatLabel(verse), "John 3:16");
    var chapter = Bookmarks.pack(42, 3, 0);
    Test.assertEqual(Bookmarks.formatLabel(chapter), "John 3");
    return true;
}
