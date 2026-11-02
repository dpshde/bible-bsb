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
        ID_BACK_READING = 7
    }

    function open(reader as ReaderView) as Void {
        var focus = reader.resolveFocus();
        var book = focus[:book] as Lang.Number;
        var chapter = focus[:chapter] as Lang.Number;
        var verse = focus[:verse] as Lang.Number;
        var bookmarked = isBookmarked(book, chapter, verse);

        var modeLabel = AppState.scroll.mode == ScrollModel.MODE_VERSE ? "Verse" : "Line";
        var ref = Books.refLabel(book, chapter, verse);
        var menu = new WatchUi.Menu2({:title => "Menu"});
        menu.addItem(new WatchUi.MenuItem("Scroll: " + modeLabel, null, ID_SCROLL_MODE, {}));
        menu.addItem(new WatchUi.MenuItem(
            bookmarked ? ("Remove " + ref) : ("Bookmark " + ref),
            null,
            ID_BOOKMARK_VERSE,
            {}));
        menu.addItem(new WatchUi.MenuItem("Bookmarks", null, ID_BOOKMARKS_LIST, {}));
        // Flipper 51d0ce4: Go to verse (NFC omitted — see SPEC divergences).
        menu.addItem(new WatchUi.MenuItem("Go to verse", null, ID_GOTO_VERSE, {}));
        menu.addItem(new WatchUi.MenuItem("Jump to chapter", null, ID_JUMP_CHAPTER, {}));
        // Alternate entry path — POKE: default vs snake book list.
        menu.addItem(new WatchUi.MenuItem("Browse by Testament", null, ID_BROWSE_TESTAMENT, {}));
        menu.addItem(new WatchUi.MenuItem("Back to reading", null, ID_BACK_READING, {}));

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
        // Spike: flat Menu2 of verse numbers (OK for John 3 = 36). POKE: Picker for Psalms 119.
        var menu = new WatchUi.Menu2({:title => "Go to verse"});
        var i;
        var maxItems = count;
        if (maxItems > 60) {
            maxItems = 60; // watchdog / Menu2 practicality
        }
        for (i = 1; i <= maxItems; i++) {
            menu.addItem(new WatchUi.MenuItem("Verse " + i, null, i, {}));
        }
        WatchUi.pushView(menu, new VersePickerDelegate(reader), WatchUi.SLIDE_LEFT);
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

class VersePickerDelegate extends WatchUi.Menu2InputDelegate {
    var _reader as ReaderView;

    function initialize(reader as ReaderView) {
        Menu2InputDelegate.initialize();
        _reader = reader;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var verse = item.getId() as Lang.Number;
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        _reader.jumpToVerse(verse);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
