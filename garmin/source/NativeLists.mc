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

    // ---- Bookmarks ---------------------------------------------------------------------
    // Verse snippets (Snippets.mc) are made when a row is first drawn (BookmarkItem), so opening
    // the list loads only the chapters of the rows on screen (was: 12 chapter loads up front).
    const ID_EMPTY = -1;
    const ID_GENRE = -3; // genre filter row (first row)
    // Dylan 2026-11-03: filter by genre like Hidden Word (public/groups.js GENRES). -1 = All.
    var bmGenre as Lang.Number = -1;
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

    //! Bookmarks per genre: [count per genre (10)], one pass over the ids.
    function genreCounts(items as Lang.Array) as Lang.Array {
        var c = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] as Lang.Array;
        for (var i = 0; i < items.size(); i++) {
            var g = Genres.ofBook(Bookmarks.unpackBook(items[i] as Lang.Number));
            c[g] = (c[g] as Lang.Number) + 1;
        }
        return c;
    }

    function genreLabel(g as Lang.Number) as Lang.String {
        return g < 0 ? "All genres" : Genres.HW_NAMES[g] as Lang.String;
    }

    function buildBookmarks() {
        var all = Bookmarks.load();
        var counts = all.size() > 0 ? genreCounts(all) : null;
        var present = 0;
        if (counts != null) {
            for (var g = 0; g < counts.size(); g++) {
                if ((counts[g] as Lang.Number) > 0) { present++; }
            }
            // Like Hidden Word's chips: a filter whose genre has no bookmarks left goes back to All.
            if (bmGenre >= 0 && (counts[bmGenre] as Lang.Number) == 0) { bmGenre = -1; }
        } else {
            bmGenre = -1;
        }
        var items = all;
        if (bmGenre >= 0) {
            items = [] as Lang.Array;
            for (var i = 0; i < all.size(); i++) {
                if (Genres.ofBook(Bookmarks.unpackBook(all[i] as Lang.Number)) == bmGenre) { items.add(all[i]); }
            }
        }
        var m = UiMenu.create(all.size() == 0 ? "No bookmarks" : "Bookmarks");
        // Filter row only when it can narrow the list (Hidden Word hides its chips for one color).
        if (present > 1 || bmGenre >= 0) {
            m.addItem(UiMenu.item(genreLabel(bmGenre), "Genre · " + items.size() + (bmGenre >= 0 ? " of " + all.size() : ""), ID_GENRE));
        }
        if (items.size() == 0) {
            // POKE: EMPTY_BOOKMARKS_HINT (critique #3): "Hold START or long-press a verse", split
            // over label + sublabel: as one sublabel Enduro 3 cuts it at "Hold START or long-…".
            m.addItem(UiMenu.item("Hold START or", "long-press a verse", ID_EMPTY));
        }
        // Dylan 2026-11-03: ranges merge at display time (Bookmarks.mergeRows): first on adjacency
        // (cheap, every bookmark), then the shown rows' verses split again by color.
        var runs = Bookmarks.mergeRows(items, null, 100000);
        var head = runs.size() > SHOW_MAX ? runs.slice(0, SHOW_MAX) : runs;
        var vs = Bookmarks.verses(head);
        var cids = HwSync.colorIds(vs);
        var rows = Bookmarks.mergeRows(vs, cids, 100000);
        // Dylan 2:48 PM: synced highlights keep their Hidden Word color: sublabel "Prayer · words…".
        var names = {};
        for (var i = 0; i < rows.size(); i++) {
            var id = rows[i] as Lang.Number;
            var cid = cids[id & 0xFFFFFF];
            var lab = null;
            if (cid != null) {
                lab = names[cid];
                if (lab == null) { lab = HwSync.colorName(cid as Lang.String); names[cid] = lab; }
            }
            m.addItem(UiMenu.bookmark(Bookmarks.formatLabel(id), lab, id));
        }
        if (runs.size() > head.size()) {
            m.addItem(UiMenu.item((runs.size() - head.size()) + " more", "Newest " + SHOW_MAX + " shown", ID_EMPTY));
        }
        if (HwSync.prop(HwSync.PROP_ON) == true) {
            m.addItem(UiMenu.item(SYNC_LABEL, syncSub(), ID_SYNC));
        }
        return m;
    }

    //! Genre picker (Bookmarks' first row): All + every genre that has bookmarks, with counts,
    //! canonical order. It replaces Bookmarks (same stack depth); a pick rebuilds Bookmarks.
    function openGenrePicker() as Void {
        var all = Bookmarks.load();
        var counts = genreCounts(all);
        var m = UiMenu.create("Genre");
        m.addItem(UiMenu.item("All genres", all.size() + "", -1));
        var focus = 0;
        var rows = 1;
        for (var g = 0; g < counts.size(); g++) {
            var n = counts[g] as Lang.Number;
            if (n > 0) {
                if (g == bmGenre) { focus = rows; }
                m.addItem(UiMenu.item(Genres.HW_NAMES[g] as Lang.String, n + "", g));
                rows++;
            }
        }
        (m as WatchUi.Menu2).setFocus(focus);
        WatchUi.switchToView(m, new GenrePickDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    function showBookmarks(focusId) as Void {
        var fresh = buildBookmarks();
        var fi = (fresh as WatchUi.Menu2).findItemById(focusId);
        (fresh as WatchUi.Menu2).setFocus(fi >= 0 ? fi : 0);
        bmMenu = fresh;
        bmVer = Bookmarks.version;
        WatchUi.switchToView(fresh, new BookmarksMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    function openBookmark(id as Lang.Number) as Void {
        var b = Bookmarks.unpackBook(id);
        var c = Bookmarks.unpackChapter(id);
        var v = Bookmarks.unpackVerse(id);
        // v9: a range opens with its verses shown gold until the first press.
        ReaderView.pendingRange = Bookmarks.isRange(id) ? [b, c, v, Bookmarks.unpackEnd(id)] : null;
        Nav.openRef(b, c, v, true); // critique #4: Home > Grid > Reader, whatever was open before
    }

    // ---- A merged row's verses (Dylan 2026-11-03) ------------------------------------------
    //! Selecting "Psalms 23:1–4" lists its verses (ref + light verse text); each one opens, or
    //! is deleted / recolored alone (only that verse's record is written).
    var rangeId as Lang.Number = 0;   // the merged row the sub-list shows
    var rangeMenu = null;
    var verseId as Lang.Number = 0;   // the verse the action menu is for
    const ID_OPEN = -10;
    const ID_RECOLOR = -11;
    const ID_DELETE = -12;

    function buildRange(rid as Lang.Number) {
        var m = UiMenu.create(Bookmarks.formatLabel(rid));
        var s = Bookmarks.unpackVerse(rid);
        for (var v = s; v <= Bookmarks.unpackEnd(rid); v++) {
            var id = (rid & 0xFFFF00) | v;
            if (Bookmarks.hasVerse(id)) { m.addItem(UiMenu.bookmark(Bookmarks.formatLabel(id), null, id)); }
        }
        return m;
    }

    function openRange(rid as Lang.Number) as Void {
        rangeId = rid;
        var m = buildRange(rid);
        rangeMenu = m;
        Nav.push(m, new RangeVersesDelegate(), WatchUi.SLIDE_LEFT);
    }

    //! After a delete: the sub-list again without that verse (or back to Bookmarks when empty).
    function refreshRange() as Void {
        var left = 0;
        for (var v = Bookmarks.unpackVerse(rangeId); v <= Bookmarks.unpackEnd(rangeId); v++) {
            if (Bookmarks.hasVerse((rangeId & 0xFFFF00) | v)) { left++; }
        }
        if (left == 0) {
            Nav.pop(WatchUi.SLIDE_RIGHT);
            backToBookmarks();
            return;
        }
        var m = buildRange(rangeId);
        rangeMenu = m;
        WatchUi.switchToView(m, new RangeVersesDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    //! Leaving the sub-list: Bookmarks underneath is rebuilt when a verse changed.
    function backToBookmarks() as Void {
        rangeMenu = null;
        if (bmMenu != null && listChanged(bmVer, Bookmarks.version)) { showBookmarks(rangeId); }
    }

    function openVerseActions(id as Lang.Number) as Void {
        verseId = id;
        var m = UiMenu.create(Bookmarks.formatLabel(id));
        m.addItem(UiMenu.item("Open", "In the reader", ID_OPEN));
        var c = HwSync.colorIds([id])[id];
        m.addItem(UiMenu.item("Recolor", c != null ? HwSync.colorName(c as Lang.String) : "Pick a color", ID_RECOLOR));
        m.addItem(UiMenu.item("Delete", "This verse only", ID_DELETE));
        Nav.push(m, new VerseActionDelegate(), WatchUi.SLIDE_LEFT);
    }

    function openRecolor() as Void {
        var m = UiMenu.create("Recolor");
        var cs = HwSync.colorChoices();
        for (var i = 0; i < cs.size(); i++) {
            m.addItem(UiMenu.item((cs[i] as Lang.Array)[1] as Lang.String, null, (cs[i] as Lang.Array)[0]));
        }
        WatchUi.switchToView(m, new RecolorDelegate(), WatchUi.SLIDE_IMMEDIATE); // replaces the action menu
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
        Perf.nav("sel");
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
        Perf.nav("sel");
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
        Perf.nav("sel");
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
        Perf.nav("sel");
        var id = item.getId() as Lang.Number;
        if (id == NativeLists.ID_EMPTY) {
            return;
        }
        if (id == NativeLists.ID_GENRE) {
            NativeLists.bmMenu = null;
            NativeLists.openGenrePicker();
            return;
        }
        if (id == NativeLists.ID_SYNC) {
            HwSync.start();
            item.setSubLabel(NativeLists.syncSub()); // "syncing..." now; onSyncFinished sets the result
            WatchUi.requestUpdate();
            return;
        }
        // A merged row ("Psalms 23:1–4") lists its verses; a single verse opens straight away
        // (critique #7: no Open/Remove step; remove it from the reader menu on that verse).
        if (Bookmarks.isRange(id)) {
            NativeLists.openRange(id);
            return;
        }
        NativeLists.openBookmark(id);
    }

    function onBack() as Void {
        NativeLists.bmMenu = null;
        Nav.pop(WatchUi.SLIDE_RIGHT);
    }
}

class RangeVersesDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        Perf.nav("sel");
        NativeLists.openVerseActions(item.getId() as Lang.Number);
    }
    function onBack() as Void {
        Nav.pop(WatchUi.SLIDE_RIGHT);
        NativeLists.backToBookmarks();
    }
}

class VerseActionDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        Perf.nav("sel");
        var a = item.getId();
        if (a == NativeLists.ID_OPEN) {
            NativeLists.rangeMenu = null;
            NativeLists.openBookmark(NativeLists.verseId);
        } else if (a == NativeLists.ID_RECOLOR) {
            NativeLists.openRecolor();
        } else if (a == NativeLists.ID_DELETE) {
            Bookmarks.removeVerse(NativeLists.verseId);
            Nav.pop(WatchUi.SLIDE_IMMEDIATE);
            NativeLists.refreshRange();
        }
    }
    function onBack() as Void { Nav.pop(WatchUi.SLIDE_RIGHT); }
}

class RecolorDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        Perf.nav("sel");
        Bookmarks.recolorVerse(NativeLists.verseId, item.getId() as Lang.String);
        Nav.pop(WatchUi.SLIDE_RIGHT);
    }
    function onBack() as Void { Nav.pop(WatchUi.SLIDE_RIGHT); }
}

class GenrePickDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Perf.nav("sel");
        NativeLists.bmGenre = item.getId() as Lang.Number;
        NativeLists.showBookmarks(NativeLists.ID_GENRE);
    }

    function onBack() as Void {
        Perf.nav("back");
        NativeLists.showBookmarks(NativeLists.ID_GENRE); // filter unchanged
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Perf.nav("sel");
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
