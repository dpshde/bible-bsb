using Toybox.Lang;
using Toybox.WatchUi;

//! Native Menu2 — Flipper ActionMenu spirit + Garmin scroll/bookmark extras.
//! Flipper order (`bible_view_action_menu.c`): Save to collection, Share via NFC, Back to reading.
module ReaderMenu2 {

    enum {
        ID_SCROLL_MODE = 1,
        ID_BOOKMARK_VERSE = 2,
        ID_BOOKMARKS_LIST = 3,
        ID_JUMP_CHAPTER = 4,
        ID_BACK_READING = 5
    }

    function open(reader as ReaderView) as Void {
        var focus = AppState.scroll.focusVerse();
        var book = focus[:book] as Lang.Number;
        var chapter = focus[:chapter] as Lang.Number;
        var verse = focus[:verse] as Lang.Number;
        var bookmarked = isBookmarked(book, chapter, verse);

        var modeLabel = AppState.scroll.mode == ScrollModel.MODE_VERSE ? "Verse" : "Line";
        // POKE: sublabel vs title-only — try "Tap to switch" subtitle on large AMOLED.
        var menu = new WatchUi.Menu2({:title => "Menu"});
        menu.addItem(new WatchUi.MenuItem("Scroll: " + modeLabel, "Verse / Line", ID_SCROLL_MODE, {}));
        // Flipper "Save to collection" → bookmark toggle (wording per SPEC).
        menu.addItem(new WatchUi.MenuItem(
            bookmarked ? "Remove bookmark" : "Bookmark verse",
            Books.name(book) + " " + chapter + ":" + verse,
            ID_BOOKMARK_VERSE,
            {}));
        menu.addItem(new WatchUi.MenuItem("Bookmarks", null, ID_BOOKMARKS_LIST, {}));
        menu.addItem(new WatchUi.MenuItem("Jump to chapter", null, ID_JUMP_CHAPTER, {}));
        // Flipper "Back to reading" — dismiss menu (NFC omitted; see SPEC divergences).
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
            _reader.showToast(AppState.scroll.mode == ScrollModel.MODE_VERSE ? "Verse scroll" : "Line scroll");
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
        if (id == ReaderMenu2.ID_JUMP_CHAPTER) {
            // Return to chapter grid (reader sits atop grid in the thin slice).
            WatchUi.popView(WatchUi.SLIDE_RIGHT); // menu
            WatchUi.popView(WatchUi.SLIDE_RIGHT); // reader
            return;
        }
        // Back to reading / default
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
