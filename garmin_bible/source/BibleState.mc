import Toybox.Lang;

class BibleState {
    // Passage state
    var bookIndex as Number;
    var chapter as Number;
    var startVerse as Number;
    var endVerse as Number;

    // Book list state
    var selectedBookIndex as Number;
    var bookScroll as Number;
    var filterIndex as Number;

    // Verse select state
    // verseSelectMode: 0 = All verses, 1 = Start verse, 2 = End verse
    var verseSelectMode as Number;

    // Navigation origin tracking
    var cameFromCollection as Boolean;

    function initialize() {
        bookIndex = 0;
        chapter = 1;
        startVerse = 1;
        endVerse = 1;
        selectedBookIndex = 0;
        bookScroll = 0;
        filterIndex = 0;
        verseSelectMode = 0;
        cameFromCollection = false;
    }

    function setPassage(b as Number, c as Number, s as Number, e as Number) as Void {
        bookIndex = b;
        chapter = c;
        startVerse = s;
        endVerse = e;
    }

    function getDisplayRef() as String {
        var bookName = BibleBooks.getBookName(bookIndex);
        var maxVerse = BibleBooks.getVerseCount(bookIndex, chapter);
        if (maxVerse > 0 && startVerse == 1 && endVerse == maxVerse) {
            return bookName + " " + chapter;
        } else if (startVerse == endVerse) {
            return bookName + " " + chapter + ":" + startVerse;
        } else {
            return bookName + " " + chapter + ":" + startVerse + "-" + endVerse;
        }
    }

    function getScriptureRef() as String {
        var osis = BibleBooks.getOsisCode(bookIndex);
        if (startVerse == endVerse) {
            return osis + "." + chapter + "." + startVerse;
        } else {
            return osis + "." + chapter + "." + startVerse + "-" + osis + "." + chapter + "." + endVerse;
        }
    }

    function getFilteredBookIndices() as Array<Number> {
        return BibleBooks.getFilteredBooks(BibleBooks.getFilterOption(filterIndex));
    }

    function getMaxVerseForCurrentChapter() as Number {
        return BibleBooks.getVerseCount(bookIndex, chapter);
    }
}
