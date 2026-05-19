import Toybox.Lang;

class BibleState {
    var bookIndex as Number;
    var chapter as Number;
    var startVerse as Number;
    var endVerse as Number;
    var filterLetter as String or Null;

    function initialize() {
        bookIndex = 0;
        chapter = 1;
        startVerse = 1;
        endVerse = 1;
        filterLetter = null;
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
}
