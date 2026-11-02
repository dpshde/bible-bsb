using Toybox.Lang;

//! Next/prev chapter resolution across book boundaries (SPEC §5).
module ChapterNav {

    class Ref {
        var book as Lang.Number;
        var chapter as Lang.Number;

        function initialize(book as Lang.Number, chapter as Lang.Number) {
            me.book = book;
            me.chapter = chapter;
        }
    }

    //! Returns next chapter, or null at Revelation 22 (no wrap to Genesis).
    function nextChapter(book as Lang.Number, chapter as Lang.Number) as Ref or Null {
        var maxCh = Books.chapterCount(book);
        if (book < 0 || book >= Books.BOOK_COUNT || chapter < 1) {
            return null;
        }
        if (chapter < maxCh) {
            return new Ref(book, chapter + 1);
        }
        // Cross book
        if (book + 1 >= Books.BOOK_COUNT) {
            return null; // Rev 22 end
        }
        return new Ref(book + 1, 1);
    }

    //! Returns previous chapter, or null at Genesis 1.
    function prevChapter(book as Lang.Number, chapter as Lang.Number) as Ref or Null {
        if (book < 0 || book >= Books.BOOK_COUNT || chapter < 1) {
            return null;
        }
        if (chapter > 1) {
            return new Ref(book, chapter - 1);
        }
        if (book == 0) {
            return null; // Gen 1 start
        }
        var prevBook = book - 1;
        return new Ref(prevBook, Books.chapterCount(prevBook));
    }

    function isBibleStart(book as Lang.Number, chapter as Lang.Number) as Lang.Boolean {
        return book == 0 && chapter == 1;
    }

    function isBibleEnd(book as Lang.Number, chapter as Lang.Number) as Lang.Boolean {
        return book == Books.BOOK_COUNT - 1 && chapter == Books.chapterCount(book);
    }
}
