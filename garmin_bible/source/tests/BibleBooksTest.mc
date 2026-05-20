import Toybox.Lang;
using Toybox.System;
using Toybox.Test;

(:test)
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

    function testFilterGReturns2(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("G");
        return books.size() == 2;
    }

    function testFilter1Returns8Books(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("1");
        return books.size() == 8;
    }

    // Numeric books also appear under their first alphabetic character filter
    // (matching Rust book_matches_filter behavior)
    function testNumericBookUnderAlphabeticFilter(logger as Test.Logger) as Boolean {
        // "1 Samuel" (index 8) should match filter "S"
        var sBooks = BibleBooks.getFilteredBooks("S");
        var has1Samuel = false;
        for (var i = 0; i < sBooks.size(); i++) {
            if (sBooks[i] == 8) {
                has1Samuel = true;
                break;
            }
        }
        if (!has1Samuel) {
            return false;
        }

        // "2 Samuel" (index 9) should also match filter "S"
        var has2Samuel = false;
        for (var i = 0; i < sBooks.size(); i++) {
            if (sBooks[i] == 9) {
                has2Samuel = true;
                break;
            }
        }
        if (!has2Samuel) {
            return false;
        }

        // "1 Kings" (index 10) should match filter "K"
        var kBooks = BibleBooks.getFilteredBooks("K");
        var has1Kings = false;
        for (var i = 0; i < kBooks.size(); i++) {
            if (kBooks[i] == 10) {
                has1Kings = true;
                break;
            }
        }
        if (!has1Kings) {
            return false;
        }

        // "1 Samuel" still matches numeric filter "1"
        var num1Books = BibleBooks.getFilteredBooks("1");
        var has1SamuelNum = false;
        for (var i = 0; i < num1Books.size(); i++) {
            if (num1Books[i] == 8) {
                has1SamuelNum = true;
                break;
            }
        }
        return has1SamuelNum;
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
