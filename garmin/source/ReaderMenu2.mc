using Toybox.Lang;
using Toybox.WatchUi;

//! Native Menu2 — Flipper ActionMenu parity (51d0ce4) + Garmin extras.
//! Flipper reader items: Save to collection, Share via NFC (skipped), Go to verse.
//! Garmin keeps scroll/bookmark/bookmarks/jump + adds Browse by Testament.
module ReaderMenu2 {

    enum {
        ID_SCROLL_MODE = 1,
        ID_BOOKMARK_VERSE = 2,
        ID_BOOKMARKS_LIST = 3,
        ID_GOTO_VERSE = 4,
        ID_JUMP_CHAPTER = 5,
        ID_BROWSE_TESTAMENT = 6,
        ID_BACK_READING = 7,
        ID_THEME = 8,
        ID_BOOKMARK_RANGE = 9
    }

    function open(reader as ReaderView) as Void {
        var focus = reader.resolveFocus();
        var book = focus[:book] as Lang.Number;
        var chapter = focus[:chapter] as Lang.Number;
        var verse = focus[:verse] as Lang.Number;
        var bookmarked = isBookmarked(book, chapter, verse);

        var ref = Books.name(book) + " " + chapter + ":" + verse; // full name, no OSIS code
        var menu = UiMenu.create("Menu");
        // UX critique #6/#3 (Dylan): six rows, action first; Menu2 opens focused on row 0 so a
        // double START bookmarks. "Jump by verse" lives in Settings; BACK = back to reading;
        // By Testament is on the home menu.
        menu.addItem(UiMenu.item(
            bookmarked ? "Remove bookmark" : "Bookmark verse",
            ref,
            ID_BOOKMARK_VERSE));
        // Flipper 51d0ce4: Go to verse (NFC omitted — see SPEC divergences).
        menu.addItem(UiMenu.item("Go to verse", null, ID_GOTO_VERSE));
        menu.addItem(UiMenu.item("Bookmarks", null, ID_BOOKMARKS_LIST));
        menu.addItem(UiMenu.item("Jump to chapter", null, ID_JUMP_CHAPTER));
        // v9: range bookmark — pick verses in the reader, START/tap saves, BACK cancels.
        menu.addItem(UiMenu.item("Bookmark range", "From " + chapter + ":" + verse, ID_BOOKMARK_RANGE));
        menu.addItem(UiMenu.item("Settings", "Scroll, theme, buzz", ID_THEME));

        Nav.push(menu, new ReaderMenu2Delegate(reader), WatchUi.SLIDE_LEFT);
    }

    function isBookmarked(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Lang.Boolean {
        var id = Bookmarks.pack(book, chapter, verse);
        var list = Bookmarks.load();
        var i;
        for (i = 0; i < list.size(); i++) {
            if (list[i] == id) {
                return true;
            }
        }
        return false;
    }

    function openVersePicker(reader as ReaderView) as Void {
        var focus = reader.resolveFocus();
        var book = focus[:book] as Lang.Number;
        var chapter = focus[:chapter] as Lang.Number;
        var count = ContentLoader.verseCount(book, chapter);
        if (count < 1) {
            count = 1;
        }
        var items = sectionRows(book, chapter);
        if (items != null) {
            // POKE: GOTO_VERSE_FALLBACK — direct verse picking stays one row away.
            items.add(["Verse…", "", -1]);
            NativeLists.openSections(reader, items);
            return;
        }
        // POKE: GOTO_VERSE_FALLBACK — no headings: straight to the verse picker.
        openVerseList(reader, count, 0);
    }

    //! A chapter's BSB section headings as [title, " (a–b)", firstVerse], or null when the
    //! chapter has none. Shared by the reader's Go to verse and the home menu's Go to….
    //! POKE: GOTO_HEADINGS_SOURCE — headings come from the bundled chapter JSON
    //! (ContentLoader.loadChapter(...)[:sections], each {:title, :startVerse}); a section runs
    //! to the verse before the next heading, ending on a verse the BSB has (Matt 17 has no 21).
    function sectionRows(book as Lang.Number, chapter as Lang.Number) as Lang.Array or Null {
        var count = ContentLoader.verseCount(book, chapter);
        if (count < 1) {
            count = 1;
        }
        // Dylan 3:01 PM: Go to verse lists the chapter's BSB section headings with their
        // verse span, "The Creation (1–25)"; selecting one jumps to its first verse.
        var data = ContentLoader.loadChapter(book, chapter);
        var secs = data != null ? data[:sections] : null;
        if (secs == null || (secs as Lang.Array).size() == 0) {
            return null;
        }
        var sa = secs as Lang.Array;
        var items = [] as Lang.Array;
        var i;
        // First heading after verse 1: verses before it stay reachable as their own row.
        var first = (sa[0] as Lang.Dictionary)[:startVerse] as Lang.Number;
        if (first > 1) {
            items.add(["Start of chapter", first == 2 ? " (1)" : " (1–" + (first - 1) + ")", 1]);
        }
        var present = ContentLoader.verseNumbers(book, chapter);
        for (i = 0; i < sa.size(); i++) {
            var st = (sa[i] as Lang.Dictionary)[:startVerse] as Lang.Number;
            var en = i + 1 < sa.size() ? ((sa[i + 1] as Lang.Dictionary)[:startVerse] as Lang.Number) - 1 : count;
            while (en > st && present.indexOf(en) < 0) {
                en--;
            }
            if (en < st) {
                en = st;
            }
            // POKE: GOTO_RANGE_LABEL — " (1–25)" with an en dash; a one-verse section is " (7)".
            var span = st == en ? st.toString() : st + "–" + en;
            items.add([(sa[i] as Lang.Dictionary)[:title] as Lang.String, " (" + span + ")", st]);
        }
        return items;
    }

    const ID_GOTO_ANY_VERSE = -1;

    //! extraPops: menus under this picker to pop on a jump (section menu = 1).
    function openVerseList(reader as ReaderView, count as Lang.Number, extraPops as Lang.Number) as Void {
        // POKE: GOTO_RANGE — chapters over GOTO_FLAT_MAX verses (Psalm 119 = 176) get a
        // range level first ("Verses 161-176"), so every verse is reachable in <= 2 lists.
        if (count > GOTO_FLAT_MAX) {
            var rm = UiMenu.create("Go to verse");
            var s = 1;
            while (s <= count) {
                var e = s + GOTO_RANGE - 1;
                if (e > count) {
                    e = count;
                }
                rm.addItem(UiMenu.item("Verses " + s + "-" + e, null, s));
                s = e + 1;
            }
            Nav.push(rm, new VerseRangeDelegate(reader, count, extraPops), WatchUi.SLIDE_LEFT);
            return;
        }
        pushVerseList(reader, 1, count, 1 + extraPops);
    }

    const GOTO_FLAT_MAX = 40;
    const GOTO_RANGE = 20;

    function pushVerseList(reader as ReaderView, from as Lang.Number, to as Lang.Number,
                           pops as Lang.Number) as Void {
        var menu = UiMenu.create("Go to verse");
        // Only verses present in the BSB text (Matt 17 skips 21: ..., 20, 22, ...).
        var f = reader.resolveFocus();
        var nums = ContentLoader.verseNumbers(f[:book] as Lang.Number, f[:chapter] as Lang.Number);
        var i;
        for (i = 0; i < nums.size(); i++) {
            var vn = nums[i] as Lang.Number;
            if (vn >= from && vn <= to) {
                menu.addItem(UiMenu.item("Verse " + vn, null, vn));
            }
        }
        Nav.push(menu, new VersePickerDelegate(reader, pops), WatchUi.SLIDE_LEFT);
    }
}

class ReaderMenu2Delegate extends WatchUi.Menu2InputDelegate {
    var _reader as ReaderView;

    function initialize(reader as ReaderView) {
        Menu2InputDelegate.initialize();
        _reader = reader;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Lang.Number;
        if (id == ReaderMenu2.ID_SCROLL_MODE) {
            NativeLists.applySetting(:scroll, UiMenu.toggledState(item));
            Nav.pop(WatchUi.SLIDE_RIGHT);
            _reader.showModeBanner();
            return;
        }
        if (id == ReaderMenu2.ID_BOOKMARK_VERSE) {
            Nav.pop(WatchUi.SLIDE_RIGHT);
            _reader.bookmarkFocusedVerse();
            return;
        }
        if (id == ReaderMenu2.ID_BOOKMARK_RANGE) {
            Nav.pop(WatchUi.SLIDE_RIGHT);
            _reader.startRange();
            return;
        }
        if (id == ReaderMenu2.ID_BOOKMARKS_LIST) {
            Nav.pop(WatchUi.SLIDE_RIGHT);
            NativeLists.openBookmarks();
            return;
        }
        if (id == ReaderMenu2.ID_GOTO_VERSE) {
            Nav.pop(WatchUi.SLIDE_RIGHT);
            ReaderMenu2.openVersePicker(_reader);
            return;
        }
        if (id == ReaderMenu2.ID_JUMP_CHAPTER) {
            Nav.pop(WatchUi.SLIDE_RIGHT); // menu
            Nav.pop(WatchUi.SLIDE_RIGHT); // reader
            return;
        }
        if (id == ReaderMenu2.ID_THEME) {
            NativeLists.openSettings(); // menu stays underneath: back returns here
            return;
        }
        if (id == ReaderMenu2.ID_BROWSE_TESTAMENT) {
            Nav.pop(WatchUi.SLIDE_RIGHT);
            NativeLists.openBrowse();
            return;
        }
        Nav.pop(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        Nav.pop(WatchUi.SLIDE_RIGHT);
    }
}

class VerseRangeDelegate extends WatchUi.Menu2InputDelegate {
    var _reader as ReaderView;
    var _count as Lang.Number;
    var _extra as Lang.Number;

    function initialize(reader as ReaderView, count as Lang.Number, extra as Lang.Number) {
        Menu2InputDelegate.initialize();
        _reader = reader;
        _count = count;
        _extra = extra;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var s = item.getId() as Lang.Number;
        var e = s + ReaderMenu2.GOTO_RANGE - 1;
        if (e > _count) {
            e = _count;
        }
        ReaderMenu2.pushVerseList(_reader, s, e, 2 + _extra);
    }

    function onBack() as Void {
        Nav.pop(WatchUi.SLIDE_RIGHT);
    }
}

class VersePickerDelegate extends WatchUi.Menu2InputDelegate {
    var _reader as ReaderView;
    var _pops as Lang.Number;

    function initialize(reader as ReaderView, pops as Lang.Number) {
        Menu2InputDelegate.initialize();
        _reader = reader;
        _pops = pops;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var verse = item.getId() as Lang.Number;
        var i;
        for (i = 0; i < _pops; i++) {
            Nav.pop(WatchUi.SLIDE_RIGHT);
        }
        _reader.jumpToVerse(verse);
    }

    function onBack() as Void {
        Nav.pop(WatchUi.SLIDE_RIGHT);
    }
}

//! Section-heading Go to: item id = first verse of the section, or ID_GOTO_ANY_VERSE.
class SectionGotoDelegate extends WatchUi.Menu2InputDelegate {
    var _reader as ReaderView;

    function initialize(reader as ReaderView) {
        Menu2InputDelegate.initialize();
        _reader = reader;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Lang.Number;
        if (id == ReaderMenu2.ID_GOTO_ANY_VERSE) {
            var f = _reader.resolveFocus();
            var count = ContentLoader.verseCount(f[:book] as Lang.Number, f[:chapter] as Lang.Number);
            ReaderMenu2.openVerseList(_reader, count < 1 ? 1 : count, 1);
            return;
        }
        Nav.pop(WatchUi.SLIDE_RIGHT);
        _reader.jumpToVerse(id);
    }

    function onBack() as Void {
        Nav.pop(WatchUi.SLIDE_RIGHT);
    }
}
