import Toybox.Lang;
using Toybox.System;
using Toybox.Test;

class BibleBooksTest {

    function testBookCount(logger as Test.Logger) as Boolean {
        var count = BibleBooks.BOOK_COUNT;
        return count == 66;
    }

    function testGenesisChapters(logger as Test.Logger) as Boolean {
        var chapters = BibleBooks.getChapterCount(0);
        return chapters == 50;
    }

    function testPsalm119Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(18, 119);
        return verses == 176;
    }

    function testJohn3Verses(logger as Test.Logger) as Boolean {
        var verses = BibleBooks.getVerseCount(42, 3);
        return verses == 36;
    }

    function testFilterOptionsCount(logger as Test.Logger) as Boolean {
        var count = BibleBooks.FILTER_COUNT;
        return count == 19;
    }

    function testFilterAllReturns66(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("All");
        return books.size() == 66;
    }

    function testFilterRReturns3(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("R");
        return books.size() == 3;
    }

    function testOsisCodeGenesis(logger as Test.Logger) as Boolean {
        var osis = BibleBooks.getOsisCode(0);
        return osis == "gen";
    }

    function testBookNameRevelation(logger as Test.Logger) as Boolean {
        var name = BibleBooks.getBookName(65);
        return name == "Revelation";
    }
}
