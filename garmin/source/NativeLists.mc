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
        Nav.push(buildSettings(), new SettingsDelegate(), WatchUi.SLIDE_LEFT);
    }

    function buildSettings() {
        // Dylan 2:56 PM: a P1Menu like every other list (UiMenu; native Menu2 layout, P1 colors).
        var m = UiMenu.create("Settings");
        m.addItem(UiMenu.toggle(SCROLL_LABEL, SCROLL_ON, SCROLL_OFF,
                                AppState.scroll.mode == ScrollModel.MODE_VERSE, :scroll));
        m.addItem(UiMenu.toggle("Dark theme", "Light on black", "Dark on white",
                                Palette.theme != Palette.THEME_LIGHT, :theme));
        m.addItem(UiMenu.toggle("Tap vibration", "Buzz on tap", "No buzz",
                                Feedback.enabled(), :vibe));
        m.addItem(UiMenu.toggle("Vibrate on scroll", "Tick on each step", "No tick",
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
        Nav.push(m, new BrowseTestamentDelegate(), WatchUi.SLIDE_LEFT);
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
        Nav.push(m, new BrowseGenreDelegate(), WatchUi.SLIDE_LEFT);
    }

    function openGenreBooks(gi as Lang.Number) as Void {
        var books = Genres.booksForGenre(gi);
        if (books.size() == 1) {
            Nav.openBook(books[0] as Lang.Number); // single-book section skips the list
            return;
        }
        var m = UiMenu.create(Genres.headerName(gi));
        var i;
        for (i = 0; i < books.size(); i++) {
            var b = books[i] as Lang.Number;
            m.addItem(UiMenu.item(Books.name(b), chaptersLabel(b), b));
        }
        Nav.push(m, new BrowseBookDelegate(), WatchUi.SLIDE_LEFT);
    }

    function chaptersLabel(b as Lang.Number) as Lang.String {
        var n = Books.chapterCount(b);
        return n == 1 ? "1 chapter" : n + " chapters";
    }

    // ---- Filter books (Flipper's 22 options) -----------------------------------------
    //! v7 (Dylan): a cell grid like the chapter grid (ChapterGridView, mode GRID_FILTER).
    const FILTER_TITLE = "Filter books";
    var filterFocus as Lang.Number = 0; // last focused filter cell (this session)

    // Critique #9: the filter grid's entry (home swipe-left) now opens Go to… (GoTo.open).

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
        Nav.push(m, new BrowseBookDelegate(), WatchUi.SLIDE_LEFT);
    }

    // ---- Bookmarks ---------------------------------------------------------------------
    // POKE: BOOKMARK_SNIPPETS — verse snippets for the newest N (each costs a chapter load).
    const SNIPPETS = 12;
    const SNIPPET_CHARS = 16; // native Menu2 sublabel on Enduro 3 fits ~17 chars: "Through Him all…" (word-boundary cut)
    const ID_EMPTY = -1;
    // POKE: BOOKMARKS_SHOWN — rows in the Bookmarks list (each Menu2 item costs memory; a synced
    // library can hold thousands). The rest are reachable from the reader (verse marks) and Go to.
    const SHOW_MAX = 100;
    const ID_SYNC = -2; // "Sync now" row (only when Hidden Word sync is on): sublabel = last result

    function openBookmarks() as Void {
        var m = buildBookmarks();
        bmMenu = m;
        bmVer = Bookmarks.version;
        Nav.push(m, new BookmarksMenuDelegate(), WatchUi.SLIDE_LEFT);
    }

    // Dylan 3:03 PM (real Enduro 3, 0.9.1): "Sync now" stayed on "syncing…" and the list didn't
    // refresh. Every sync end calls onSyncFinished (HwSync.onFinished): the open Bookmarks menu
    // gets its list rebuilt (same focus, same stack depth) or just its Sync row updated, and the
    // home menu's Bookmarks sublabel is updated. Reopening Bookmarks always builds it fresh.
    var bmMenu = null;          // the Bookmarks menu last opened (null when closed)
    var bmVer as Lang.Number = -1; // Bookmarks.version it was built from
    var homeMenu = null;        // the home menu, while open (PickList.HomeMenu2Delegate.open)

    function onSyncFinished() as Void {
        var hm = homeMenu;
        if (hm != null) {
            var hi = (hm as WatchUi.Menu2).findItemById(:bookmarks);
            if (hi >= 0) {
                ((hm as WatchUi.Menu2).getItem(hi) as WatchUi.MenuItem).setSubLabel(HwSync.bookmarksLine(Bookmarks.load().size()));
            }
        }
        var m = bmMenu;
        if (m == null || WatchUi.getCurrentView()[0] != m) {
            bmMenu = null; // not on screen: the next open builds it fresh
            WatchUi.requestUpdate();
            return;
        }
        if (listChanged(bmVer, Bookmarks.version)) {
            var fresh = buildBookmarks();
            var fi = (fresh as WatchUi.Menu2).findItemById(UiMenu.lastFocusId);
            (fresh as WatchUi.Menu2).setFocus(fi >= 0 ? fi : 0);
            bmMenu = fresh;
            bmVer = Bookmarks.version;
            WatchUi.switchToView(fresh, new BookmarksMenuDelegate(), WatchUi.SLIDE_IMMEDIATE); // replaces: depth unchanged
            return;
        }
        var si = (m as WatchUi.Menu2).findItemById(ID_SYNC);
        if (si >= 0) {
            var it = (m as WatchUi.Menu2).getItem(si) as WatchUi.MenuItem;
            it.setLabel(SYNC_LABEL);
            it.setSubLabel(syncSub());
        }
        WatchUi.requestUpdate();
    }

    function listChanged(builtVer as Lang.Number, nowVer as Lang.Number) as Lang.Boolean {
        return builtVer != nowVer;
    }

    const SYNC_LABEL = "Sync now";

    function syncSub() as Lang.String or Null {
        var st = HwSync.shortStatus;
        return st.length() > 0 ? st : null;
    }

    function buildBookmarks() {
        var items = Bookmarks.load();
        var m = UiMenu.create(items.size() == 0 ? "No bookmarks" : "Bookmarks");
        if (items.size() == 0) {
            // POKE: EMPTY_BOOKMARKS_HINT (critique #3): "Hold START or long-press a verse", split
            // over label + sublabel: as one sublabel Enduro 3 cuts it at "Hold START or long-…".
            m.addItem(UiMenu.item("Hold START or", "long-press a verse", ID_EMPTY));
        }
        var i;
        var shown = items.size() > SHOW_MAX ? SHOW_MAX : items.size();
        // Dylan 2:48 PM: synced highlights keep their Hidden Word color: sublabel "Prayer · words…".
        // Text only (native Menu2, built-in fonts); no swatch, since a highlight color can be
        // green or blue, which the watch UI never draws.
        var colors = HwSync.colorLabels(items.slice(0, shown));
        for (i = 0; i < shown; i++) {
            var id = items[i] as Lang.Number;
            var sn = i < SNIPPETS ? snippet(id) : null;
            var col = colors[id];
            var sub = col == null ? sn : (sn == null ? col as Lang.String : (col as Lang.String) + " · " + sn);
            m.addItem(UiMenu.item(Bookmarks.formatLabel(id), sub, id));
        }
        if (items.size() > shown) {
            m.addItem(UiMenu.item((items.size() - shown) + " more", "Newest " + SHOW_MAX + " shown", ID_EMPTY));
        }
        if (HwSync.prop(HwSync.PROP_ON) == true) {
            m.addItem(UiMenu.item(SYNC_LABEL, syncSub(), ID_SYNC));
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

    function openBookmark(id as Lang.Number) as Void {
        var b = Bookmarks.unpackBook(id);
        var c = Bookmarks.unpackChapter(id);
        var v = Bookmarks.unpackVerse(id);
        // v9: a range opens with its verses shown gold until the first press.
        ReaderView.pendingRange = Bookmarks.isRange(id) ? [b, c, v, Bookmarks.unpackEnd(id)] : null;
        Nav.openRef(b, c, v, true); // critique #4: Home > Grid > Reader, whatever was open before
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
        Nav.push(m, new SectionGotoDelegate(reader), WatchUi.SLIDE_LEFT);
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
        Nav.pop(WatchUi.SLIDE_RIGHT);
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
        Nav.pop(WatchUi.SLIDE_RIGHT);
    }
}

class BrowseBookDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Nav.openBook(item.getId() as Lang.Number); // critique #4: Home > Grid(book), menus closed
    }

    function onBack() as Void {
        Nav.pop(WatchUi.SLIDE_RIGHT);
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
        if (id == NativeLists.ID_SYNC) {
            HwSync.start();
            item.setSubLabel(NativeLists.syncSub()); // "syncing..." now; onSyncFinished sets the result
            WatchUi.requestUpdate();
            return;
        }
        // Critique #7: START opens the bookmark (no Open/Remove step). Remove it from the reader
        // menu ("Remove bookmark") on that verse.
        NativeLists.openBookmark(id);
    }

    function onBack() as Void {
        NativeLists.bmMenu = null;
        Nav.pop(WatchUi.SLIDE_RIGHT);
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
        Nav.pop(WatchUi.SLIDE_RIGHT);
    }
}
