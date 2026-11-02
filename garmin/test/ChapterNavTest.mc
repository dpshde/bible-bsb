using Toybox.Lang;
using Toybox.Test;

(:test)
function testNextChapterSameBook(logger as Logger) as Lang.Boolean {
    var n = ChapterNav.nextChapter(42, 3);
    Test.assert(n != null);
    Test.assertEqual(n.book, 42);
    Test.assertEqual(n.chapter, 4);
    return true;
}

(:test)
function testNextChapterCrossBookMalachiToMatthew(logger as Logger) as Lang.Boolean {
    // Malachi index 38, 4 chapters → Matthew 39 ch 1
    var n = ChapterNav.nextChapter(38, 4);
    Test.assert(n != null);
    Test.assertEqual(n.book, 39);
    Test.assertEqual(n.chapter, 1);
    return true;
}

(:test)
function testPrevChapterCrossBookMatthewToMalachi(logger as Logger) as Lang.Boolean {
    var p = ChapterNav.prevChapter(39, 1);
    Test.assert(p != null);
    Test.assertEqual(p.book, 38);
    Test.assertEqual(p.chapter, 4);
    return true;
}

(:test)
function testGenesis1NoPrev(logger as Logger) as Lang.Boolean {
    var p = ChapterNav.prevChapter(0, 1);
    Test.assert(p == null);
    Test.assert(ChapterNav.isBibleStart(0, 1));
    return true;
}

(:test)
function testRevelation22NoNext(logger as Logger) as Lang.Boolean {
    var n = ChapterNav.nextChapter(65, 22);
    Test.assert(n == null);
    Test.assert(ChapterNav.isBibleEnd(65, 22));
    return true;
}

(:test)
function testJohn21ToActs1(logger as Logger) as Lang.Boolean {
    var n = ChapterNav.nextChapter(42, 21);
    Test.assert(n != null);
    Test.assertEqual(n.book, 43);
    Test.assertEqual(n.chapter, 1);
    return true;
}
