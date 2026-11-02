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
        ID_THEME = 8
    }

    function open(reader as ReaderView) as Void {
        var focus = reader.resolveFocus();
        var book = focus[:book] as Lang.Number;
        var chapter = focus[:chapter] as Lang.Number;
        var verse = focus[:verse] as Lang.Number;
        var bookmarked = isBookmarked(book, chapter, verse);

        var modeLabel = AppState.scroll.mode == ScrollModel.MODE_VERSE ? "Verse" : "Line";
        var ref = Books.refLabel(book, chapter, verse);
        var menu = new ThemedMenu("Menu");
        menu.addItem(new ThemedMenuItem("Scroll: " + modeLabel, null, ID_SCROLL_MODE));
        menu.addItem(new ThemedMenuItem(
            bookmarked ? ("Remove " + ref) : ("Bookmark " + ref),
            null,
            ID_BOOKMARK_VERSE));
        menu.addItem(new ThemedMenuItem("Bookmarks", null, ID_BOOKMARKS_LIST));
        // Flipper 51d0ce4: Go to verse (NFC omitted — see SPEC divergences).
        menu.addItem(new ThemedMenuItem("Go to verse", null, ID_GOTO_VERSE));
        menu.addItem(new ThemedMenuItem("Jump to chapter", null, ID_JUMP_CHAPTER));
        // Alternate entry path — POKE: default vs snake book list.
        menu.addItem(new ThemedMenuItem("By Testament", null, ID_BROWSE_TESTAMENT));
        menu.addItem(new ThemedMenuItem("Theme: " + Palette.themeLabel(), null, ID_THEME));
        menu.addItem(new ThemedMenuItem("Back to reading", null, ID_BACK_READING));

        WatchUi.pushView(menu, new ReaderMenu2Delegate(reader), WatchUi.SLIDE_LEFT);
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
        // POKE: GOTO_RANGE — chapters over GOTO_FLAT_MAX verses (Psalm 119 = 176) get a
        // range level first ("Verses 161-176"), so every verse is reachable in <= 2 lists.
        if (count > GOTO_FLAT_MAX) {
            var rm = new ThemedMenu("Go to verse");
            var s = 1;
            while (s <= count) {
                var e = s + GOTO_RANGE - 1;
                if (e > count) {
                    e = count;
                }
                rm.addItem(new ThemedMenuItem("Verses " + s + "-" + e, null, s));
                s = e + 1;
            }
            WatchUi.pushView(rm, new VerseRangeDelegate(reader, count), WatchUi.SLIDE_LEFT);
            return;
        }
        pushVerseList(reader, 1, count, 1);
    }

    const GOTO_FLAT_MAX = 40;
    const GOTO_RANGE = 20;

    function pushVerseList(reader as ReaderView, from as Lang.Number, to as Lang.Number,
                           pops as Lang.Number) as Void {
        var menu = new ThemedMenu("Go to verse");
        var i;
        for (i = from; i <= to; i++) {
            menu.addItem(new ThemedMenuItem("Verse " + i, null, i));
        }
        WatchUi.pushView(menu, new VersePickerDelegate(reader, pops), WatchUi.SLIDE_LEFT);
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
            AppState.scroll.toggleMode();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            _reader.showModeBanner();
            return;
        }
        if (id == ReaderMenu2.ID_BOOKMARK_VERSE) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            _reader.bookmarkFocusedVerse();
            return;
        }
        if (id == ReaderMenu2.ID_BOOKMARKS_LIST) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.pushView(new BookmarksView(), new BookmarksDelegate(), WatchUi.SLIDE_UP);
            return;
        }
        if (id == ReaderMenu2.ID_GOTO_VERSE) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            ReaderMenu2.openVersePicker(_reader);
            return;
        }
        if (id == ReaderMenu2.ID_JUMP_CHAPTER) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT); // menu
            WatchUi.popView(WatchUi.SLIDE_RIGHT); // reader
            return;
        }
        if (id == ReaderMenu2.ID_THEME) {
            Palette.toggleTheme();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.requestUpdate();
            return;
        }
        if (id == ReaderMenu2.ID_BROWSE_TESTAMENT) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            WatchUi.pushView(new TestamentListView(), new TestamentListDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class VerseRangeDelegate extends WatchUi.Menu2InputDelegate {
    var _reader as ReaderView;
    var _count as Lang.Number;

    function initialize(reader as ReaderView, count as Lang.Number) {
        Menu2InputDelegate.initialize();
        _reader = reader;
        _count = count;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var s = item.getId() as Lang.Number;
        var e = s + ReaderMenu2.GOTO_RANGE - 1;
        if (e > _count) {
            e = _count;
        }
        ReaderMenu2.pushVerseList(_reader, s, e, 2);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
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
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        _reader.jumpToVerse(verse);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
