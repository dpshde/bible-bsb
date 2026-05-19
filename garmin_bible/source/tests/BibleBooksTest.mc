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
        return count == 22;
    }

    function testFilterAllReturns66(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("All");
        return books.size() == 66;
    }

    function testFilterRReturns3(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("R");
        return books.size() == 3;
    }

    function testFilterGReturns3(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("G");
        return books.size() == 3;
    }

    function testFilter1Returns8Books(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("1");
        return books.size() == 8;
    }

    function testFilterCountMatchesOptions(logger as Test.Logger) as Boolean {
        var count = BibleBooks.FILTER_COUNT;
        var actualOptions = 1; // "All"
        var seen = [] as Array<String>;
        for (var i = 0; i < BibleBooks.BOOK_COUNT; i++) {
            var name = BibleBooks.getBookName(i) as String;
            if (name.length() > 0) {
                var initialOrNull = name.substring(0, 1);
                if (initialOrNull != null) {
                    var initial = initialOrNull as String;
                    var alreadySeen = false;
                    for (var j = 0; j < seen.size(); j++) {
                        if (seen[j].equals(initial)) {
                            alreadySeen = true;
                            break;
                        }
                    }
                    if (!alreadySeen) {
                        seen.add(initial);
                        actualOptions = actualOptions + 1;
                    }
                }
            }
        }
        return count == actualOptions;
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
