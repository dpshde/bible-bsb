using Toybox.Lang;
using Toybox.WatchUi;

//! Home menu "Go to…" (UX critique #1, pair-mode with Dylan): letter > book > chapter grid >
//! section headings > reader. Native Menu2 lists (UiMenu) except the existing chapter grid.
//! Also the home list's swipe-left (critique #9: replaces the filter grid).
module GoTo {
    const ID_VERSE = -1; // "Pick a verse…" row
    // POKE: GOTO_LETTER_DIGITS — numbered books (1 Samuel … 3 John) share one row.
    const DIGITS = "1–3";

    //! Letters that start a book name, A..Z order, then DIGITS when any book starts with one.
    function letters() as Lang.Array<Lang.String> {
        var out = [] as Lang.Array<Lang.String>;
        var digits = false;
        for (var i = 0; i < Books.BOOK_COUNT; i++) {
            var c = Books.name(i).substring(0, 1) as Lang.String;
            if ("0123456789".find(c) != null) { digits = true; continue; }
            if (out.indexOf(c) < 0) { out.add(c); }
        }
        for (var i = 1; i < out.size(); i++) { // insertion sort, 18 letters
            var x = out[i];
            var j = i - 1;
            while (j >= 0 && (out[j] as Lang.String).compareTo(x) > 0) { out[j + 1] = out[j]; j--; }
            out[j + 1] = x;
        }
        if (digits) { out.add(DIGITS); }
        return out;
    }

    //! Books under a letter row, canonical order.
    function booksFor(letter as Lang.String) as Lang.Array<Lang.Number> {
        var out = [] as Lang.Array<Lang.Number>;
        for (var i = 0; i < Books.BOOK_COUNT; i++) {
            var c = Books.name(i).substring(0, 1) as Lang.String;
            var isDigit = "0123456789".find(c) != null;
            if (letter.equals(DIGITS) ? isDigit : c.equals(letter)) { out.add(i); }
        }
        return out;
    }

    function open() as Void {
        var m = UiMenu.create("Go to");
        var ls = letters();
        for (var i = 0; i < ls.size(); i++) {
            var bs = booksFor(ls[i]);
            m.addItem(UiMenu.item(ls[i], bs.size() == 1 ? Books.name(bs[0]) : bs.size() + " books", ls[i]));
        }
        Nav.push(m, new GoToLetterDelegate(), Nav.IN);
    }

    function openLetter(letter as Lang.String) as Void {
        var bs = booksFor(letter);
        if (bs.size() == 1) { openBook(bs[0]); return; }
        var m = UiMenu.create(letter.equals(DIGITS) ? "Books 1–3" : "Books: " + letter);
        for (var i = 0; i < bs.size(); i++) {
            m.addItem(UiMenu.item(Books.name(bs[i]), NativeLists.chaptersLabel(bs[i]), bs[i]));
        }
        Nav.push(m, new GoToBookDelegate(), Nav.IN);
    }

    //! The chapter grid in pick mode: START on a chapter opens its headings (not the reader).
    function openBook(book as Lang.Number) as Void {
        AppState.selectedBook = book;
        AppState.selectedChapter = LastReadApp.chapterFor(book);
        if (Books.chapterCount(book) == 1) { openChapter(book, 1); return; }
        var v = new ChapterGridView();
        v.pickOnly = true;
        Nav.push(v, new ChapterGridDelegate(), Nav.IN);
    }

    //! Section headings of one chapter, then "Pick a verse…".
    function openChapter(book as Lang.Number, chapter as Lang.Number) as Void {
        var rows = ReaderMenu2.sectionRows(book, chapter);
        if (rows == null) {
            // POKE: GOTO_NO_HEADINGS — a chapter without headings goes straight to its verses.
            openVerses(book, chapter);
            return;
        }
        var m = UiMenu.create(Books.name(book) + " " + chapter);
        for (var i = 0; i < rows.size(); i++) {
            var r = rows[i] as Lang.Array;
            // POKE: GOTO_RANGE_LABEL — label "The Creation (1–25)", no sublabel. Menu2 clips a
            // long label at the round edge; move the span to the sublabel if that bites.
            m.addItem(UiMenu.item((r[0] as Lang.String) + (r[1] as Lang.String), null, r[2] as Lang.Number));
        }
        m.addItem(UiMenu.item("Pick a verse…", null, ID_VERSE));
        Nav.push(m, new GoToSectionDelegate(book, chapter), Nav.IN);
    }

    // POKE: GOTO_VERSE_GROUP — long chapters (Psalm 119) list verse groups of GROUP first.
    const FLAT_MAX = 40;
    const GROUP = 20;

    function openVerses(book as Lang.Number, chapter as Lang.Number) as Void {
        var nums = ContentLoader.verseNumbers(book, chapter);
        var last = nums.size() > 0 ? nums[nums.size() - 1] as Lang.Number : 1;
        if (nums.size() > FLAT_MAX) {
            var m = UiMenu.create(Books.name(book) + " " + chapter);
            for (var s = 1; s <= last; s += GROUP) {
                var e = s + GROUP - 1 > last ? last : s + GROUP - 1;
                m.addItem(UiMenu.item("Verses " + s + "–" + e, null, s));
            }
            Nav.push(m, new GoToGroupDelegate(book, chapter), Nav.IN);
            return;
        }
        openVerseRange(book, chapter, 1, last);
    }

    function openVerseRange(book as Lang.Number, chapter as Lang.Number, from as Lang.Number, to as Lang.Number) as Void {
        var nums = ContentLoader.verseNumbers(book, chapter); // only verses the BSB has
        var m = UiMenu.create(Books.name(book) + " " + chapter);
        for (var i = 0; i < nums.size(); i++) {
            var vn = nums[i] as Lang.Number;
            if (vn >= from && vn <= to) { m.addItem(UiMenu.item("Verse " + vn, null, vn)); }
        }
        Nav.push(m, new GoToVerseDelegate(book, chapter), Nav.IN);
    }
}

class GoToLetterDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void { GoTo.openLetter(item.getId() as Lang.String); }
    function onBack() as Void { Nav.pop(Nav.OUT); }
}

class GoToBookDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void { GoTo.openBook(item.getId() as Lang.Number); }
    function onBack() as Void { Nav.pop(Nav.OUT); }
}

class GoToSectionDelegate extends WatchUi.Menu2InputDelegate {
    var _b as Lang.Number;
    var _c as Lang.Number;
    function initialize(b as Lang.Number, c as Lang.Number) { Menu2InputDelegate.initialize(); _b = b; _c = c; }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var v = item.getId() as Lang.Number;
        if (v == GoTo.ID_VERSE) { GoTo.openVerses(_b, _c); return; }
        Nav.openRef(_b, _c, v, true);
    }
    function onBack() as Void { Nav.pop(Nav.OUT); }
}

class GoToGroupDelegate extends WatchUi.Menu2InputDelegate {
    var _b as Lang.Number;
    var _c as Lang.Number;
    function initialize(b as Lang.Number, c as Lang.Number) { Menu2InputDelegate.initialize(); _b = b; _c = c; }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var s = item.getId() as Lang.Number;
        GoTo.openVerseRange(_b, _c, s, s + GoTo.GROUP - 1);
    }
    function onBack() as Void { Nav.pop(Nav.OUT); }
}

class GoToVerseDelegate extends WatchUi.Menu2InputDelegate {
    var _b as Lang.Number;
    var _c as Lang.Number;
    function initialize(b as Lang.Number, c as Lang.Number) { Menu2InputDelegate.initialize(); _b = b; _c = c; }
    function onSelect(item as WatchUi.MenuItem) as Void { Nav.openRef(_b, _c, item.getId() as Lang.Number, true); }
    function onBack() as Void { Nav.pop(Nav.OUT); }
}
