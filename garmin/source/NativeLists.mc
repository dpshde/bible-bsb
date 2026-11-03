using Toybox.Lang;
using Toybox.WatchUi;

//! v4 (Dylan 4:39 PM): Browse, Bookmarks, Filter books and Go to verse are native Menu2
//! (via UiMenu, POKE: MENU_STYLE). Label = reference or name; sublabel = count, heading or
//! verse snippet. The book list, chapter grid and reader stay custom.
module NativeLists {

    // ---- Settings (docs/SETTINGS_PARITY.md) ------------------------------------------
    // POKE: SCROLL_LABEL — "Jump by verse" on = verse mode, off = line by line.
    const SCROLL_LABEL = "Jump by verse";
    const SCROLL_ON = "One verse per press";
    const SCROLL_OFF = "One line per press";

    function scrollItem(id as Lang.Object) {
        return UiMenu.toggle(SCROLL_LABEL, SCROLL_ON, SCROLL_OFF,
                             AppState.scroll.mode == ScrollModel.MODE_VERSE, id);
    }

    //! Settings is a gold CustomMenu on every target: Menu2 forces a green system switch on
    //! ToggleMenuItem and lets the rows above/below focus run into the round edge. Here rows are
    //! 30% of the screen (only focus +/- 1 on screen) and the sublabel states the value.
    function openSettings() as Void {
        WatchUi.pushView(buildSettings(), new SettingsDelegate(), WatchUi.SLIDE_LEFT);
    }

    function buildSettings() {
        var m = new ThemedMenu("Settings");
        m.addItem(new ThemedToggleItem(SCROLL_LABEL, SCROLL_ON, SCROLL_OFF,
                                       AppState.scroll.mode == ScrollModel.MODE_VERSE, :scroll));
        m.addItem(new ThemedToggleItem("Dark theme", "Light on black", "Dark on white",
                                       Palette.theme != Palette.THEME_LIGHT, :theme));
        m.addItem(new ThemedToggleItem("Tap vibration", "Buzz on tap", "No buzz",
                                       Feedback.enabled(), :vibe));
        m.addItem(new ThemedToggleItem("Vibrate on scroll", "Tick on each step", "No tick",
                                       Feedback.stepEnabled(), :vibeScroll));
        return m;
    }

    //! Apply one setting; every value persists in Application.Storage.
    function applySetting(id, on as Lang.Boolean) as Void {
        if (id == :scroll) {
            var want = on ? ScrollModel.MODE_VERSE : ScrollModel.MODE_INCREMENTAL;
            if (AppState.scroll.mode != want) {
                AppState.scroll.toggleMode();
            }
        } else if (id == :theme) {
            if ((Palette.theme != Palette.THEME_LIGHT) != on) {
                Palette.toggleTheme();
                PickList.invalidate();
            }
        } else if (id == :vibe) {
            Feedback.setEnabled(on);
            if (on) {
                Feedback.tick();
            }
        } else if (id == :vibeScroll) {
            Feedback.setStepEnabled(on);
            if (on) {
                Feedback.step(); // a sample detent
            }
        }
    }

    // ---- Browse: Testament -> section (genre) -> books -------------------------------
    function openBrowse() as Void {
        var m = UiMenu.create("Browse");
        m.addItem(UiMenu.item("Old Testament", "39 books", 0));
        m.addItem(UiMenu.item("New Testament", "27 books", 1));
        WatchUi.pushView(m, new BrowseTestamentDelegate(), WatchUi.SLIDE_LEFT);
    }

    function openGenres(testament as Lang.Number) as Void {
        var m = UiMenu.create(testament == 0 ? "Old Testament" : "New Testament");
        var gs = Genres.genresForTestament(testament);
        var i;
        for (i = 0; i < gs.size(); i++) {
            var gi = gs[i] as Lang.Number;
            var books = Genres.booksForGenre(gi);
            var sub = books.size() == 1 ? Books.name(books[0] as Lang.Number) : books.size() + " books";
            m.addItem(UiMenu.item(Genres.headerName(gi), sub, gi));
        }
        WatchUi.pushView(m, new BrowseGenreDelegate(), WatchUi.SLIDE_LEFT);
    }

    function openGenreBooks(gi as Lang.Number) as Void {
        var books = Genres.booksForGenre(gi);
        if (books.size() == 1) {
            PickList.openBook(books[0] as Lang.Number); // single-book section skips the list
            return;
        }
        var m = UiMenu.create(Genres.headerName(gi));
        var i;
        for (i = 0; i < books.size(); i++) {
            var b = books[i] as Lang.Number;
            m.addItem(UiMenu.item(Books.name(b), chaptersLabel(b), b));
        }
        WatchUi.pushView(m, new BrowseBookDelegate(), WatchUi.SLIDE_LEFT);
    }

    function chaptersLabel(b as Lang.Number) as Lang.String {
        var n = Books.chapterCount(b);
        return n == 1 ? "1 chapter" : n + " chapters";
    }

    // ---- Filter books (Flipper's 22 options) -----------------------------------------
    //! v7 (Dylan): a cell grid like the chapter grid (ChapterGridView, mode GRID_FILTER).
    const FILTER_TITLE = "Filter books";
    var filterFocus as Lang.Number = 0; // last focused filter cell (this session)

    function openFilter() as Void {
        var v = new ChapterGridView();
        v.setFilterMode();
        WatchUi.pushView(v, new ChapterGridDelegate(), WatchUi.SLIDE_LEFT);
    }

    //! Grid subtitle for a filter cell: its books by name when few, else the count.
    function filterSummary(idx as Lang.Number) as Lang.String {
        var books = PickList.booksForFilter(idx);
        if (books.size() == 0) {
            return "No books";
        }
        if (idx == 0) {
            return "All " + books.size() + " books";
        }
        if (books.size() <= 3) {
            var sub = "";
            var k;
            for (k = 0; k < books.size(); k++) {
                sub += (k > 0 ? ", " : "") + Books.name(books[k] as Lang.Number);
            }
            return sub;
        }
        return books.size() + " books";
    }

    function openFiltered(idx as Lang.Number) as Void {
        var books = PickList.booksForFilter(idx);
        var title = idx == 0 ? "All books" : (idx >= 19 ? "Books: 1–3" : "Books: " + PickList.FILTER_LABELS[idx]);
        // Native Menu2 like Browse (label = book, sublabel = chapter count); was a custom PickList
        // with a solid gold focus box.
        var m = UiMenu.create(title);
        var i;
        for (i = 0; i < books.size(); i++) {
            var b = books[i] as Lang.Number;
            m.addItem(UiMenu.item(Books.name(b), chaptersLabel(b), b));
        }
        WatchUi.pushView(m, new BrowseBookDelegate(), WatchUi.SLIDE_LEFT);
    }

    // ---- Bookmarks ---------------------------------------------------------------------
    // POKE: BOOKMARK_SNIPPETS — verse snippets for the newest N (each costs a chapter load).
    const SNIPPETS = 12;
    const SNIPPET_CHARS = 16; // native Menu2 sublabel on Enduro 3 fits ~17 chars: "Through Him all…" (word-boundary cut)
    const ID_EMPTY = -1;

    function openBookmarks() as Void {
        WatchUi.pushView(buildBookmarks(), new BookmarksMenuDelegate(), WatchUi.SLIDE_UP);
    }

    function buildBookmarks() {
        var m = UiMenu.create("Bookmarks");
        var items = Bookmarks.load();
        if (items.size() == 0) {
            m.addItem(UiMenu.item("No bookmarks yet", "Long-press a verse", ID_EMPTY));
            return m;
        }
        var i;
        for (i = 0; i < items.size(); i++) {
            var id = items[i] as Lang.Number;
            m.addItem(UiMenu.item(Bookmarks.formatLabel(id), i < SNIPPETS ? snippet(id) : null, id));
        }
        return m;
    }

    function snippet(id as Lang.Number) as Lang.String or Null {
        var v = Bookmarks.unpackVerse(id);
        if (v <= 0) {
            return null;
        }
        var t = ContentLoader.verseText(Bookmarks.unpackBook(id), Bookmarks.unpackChapter(id), v);
        if (t == null) {
            return null;
        }
        var s = ContentLoader.plainVerseText(t as Lang.String);
        if (s.length() <= SNIPPET_CHARS) {
            return s;
        }
        s = s.substring(0, SNIPPET_CHARS + 1); // +1: a word ending exactly at the limit stays
        var k = RoundLayout.lastSpaceAt(s);
        return (k > 0 ? s.substring(0, k) : s) + "…";
    }

    function openBookmarkActions(id as Lang.Number, parent) as Void {
        var m = UiMenu.create(Bookmarks.formatLabel(id));
        m.addItem(UiMenu.item("Open", null, :open));
        m.addItem(UiMenu.item("Remove", null, :remove)); // no sublabel: the bottom row clips on Enduro 3
        WatchUi.pushView(m, new BookmarkActionDelegate(id, parent), WatchUi.SLIDE_LEFT);
    }

    function openBookmark(id as Lang.Number) as Void {
        var b = Bookmarks.unpackBook(id);
        var c = Bookmarks.unpackChapter(id);
        var v = Bookmarks.unpackVerse(id);
        if (v > 1) {
            LastReadApp.resumeVerse = v; // reader lands on the bookmarked verse
            LastReadApp.pending = [b, c, v];
        }
        ReaderView.openFor(b, c);
    }

    // ---- Go to verse (section headings) -------------------------------------------------
    //! items: [title, " (a–b)", firstVerse] (firstVerse -1 = "Verse…").
    //! Go to verse stays a CustomMenu on every target: Menu2 cuts long section headings at the
    //! round edge, while ThemedWrapItem wraps each heading to a 2-row pyramid and keeps the
    //! verse range " (1–4)" whole on the last row (gold text focus, no pill).
    function openSections(reader as ReaderView, items as Lang.Array) as Void {
        var m = new ThemedMenu("Go to verse");
        var i;
        for (i = 0; i < items.size(); i++) {
            var it = items[i] as Lang.Array;
            var span = it[1] as Lang.String;
            var label = it[0] as Lang.String;
            if ((it[2] as Lang.Number) < 0) {
                m.addItem(new ThemedMenuItem(label, "Pick any verse", it[2] as Lang.Number));
            } else {
                m.addItem(new ThemedWrapItem(label, span, it[2] as Lang.Number));
            }
        }
        WatchUi.pushView(m, new SectionGotoDelegate(reader), WatchUi.SLIDE_LEFT);
    }
}

class BrowseTestamentDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        NativeLists.openGenres(item.getId() as Lang.Number);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class BrowseGenreDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        NativeLists.openGenreBooks(item.getId() as Lang.Number);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class BrowseBookDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        PickList.openBook(item.getId() as Lang.Number);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class BookmarksMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Lang.Number;
        if (id == NativeLists.ID_EMPTY) {
            return;
        }
        NativeLists.openBookmarkActions(id, WatchUi.getCurrentView()[0]);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class BookmarkActionDelegate extends WatchUi.Menu2InputDelegate {
    var _id as Lang.Number;
    var _parent;

    function initialize(id as Lang.Number, parent) {
        Menu2InputDelegate.initialize();
        _id = id;
        _parent = parent;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var a = item.getId();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        if (a == :open) {
            NativeLists.openBookmark(_id);
            return;
        }
        if (a == :remove) {
            Bookmarks.toggle(Bookmarks.unpackBook(_id), Bookmarks.unpackChapter(_id), Bookmarks.unpackVerse(_id));
            var p = _parent as WatchUi.Menu2;
            var idx = p.findItemById(_id);
            if (idx >= 0) {
                p.deleteItem(idx);
            }
            if (Bookmarks.load().size() == 0) {
                p.addItem(UiMenu.item("No bookmarks yet", "Long-press a verse", NativeLists.ID_EMPTY));
            }
            WatchUi.requestUpdate();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        NativeLists.applySetting(item.getId(), UiMenu.toggledState(item));
        if (item.getId() == :theme) {
            // Repaint the whole menu in the new Dark/Light palette (menu background included).
            var m = NativeLists.buildSettings();
            m.setFocus(1);
            WatchUi.switchToView(m, new SettingsDelegate(), WatchUi.SLIDE_IMMEDIATE);
            return;
        }
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
