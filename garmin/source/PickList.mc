using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Round, scrolling pick list shared by every filter/browse level (Flipper parity).
//! Rows are sized to the circle chord at their y; the window scrolls to keep focus visible.
module PickList {
    //! Flipper BIBLE_FILTER_LABELS order (bible_books.c): All + 21 initials.
    const FILTER_LABELS = ["All", "A", "C", "D", "E", "G", "H", "I", "J", "K", "L",
        "M", "N", "O", "P", "R", "S", "T", "Z", "1", "2", "3"];

    //! Flipper get_filtered_books(): "All" = 66 books; else books whose name starts with the label.
    function booksForFilter(idx as Lang.Number) as Lang.Array {
        var out = [] as Lang.Array;
        var b;
        for (b = 0; b < Books.BOOK_COUNT; b++) {
            if (idx == 0 || Books.name(b).substring(0, 1).equals(FILTER_LABELS[idx])) {
                out.add(b);
            }
        }
        return out;
    }

    function bookLabels(books as Lang.Array) as Lang.Array {
        var out = [] as Lang.Array;
        var i;
        for (i = 0; i < books.size(); i++) {
            out.add(Books.name(books[i] as Lang.Number));
        }
        return out;
    }

    // Last drawn layout (touch hit-test): first row y, row height, first index, visible rows.
    var lastTop as Lang.Number = 0;
    var lastRowH as Lang.Number = 0;
    var lastStart as Lang.Number = 0;
    var lastVis as Lang.Number = 0;

    function indexAtY(y as Lang.Number, n as Lang.Number) as Lang.Number {
        if (lastRowH <= 0 || y < lastTop) {
            return -1;
        }
        var r = (y - lastTop) / lastRowH;
        var i = lastStart + r;
        return (r < lastVis && i < n) ? i : -1;
    }

    // POKE: PICKLIST_PAD — px kept clear on each side of a row inside its chord.
    const ROW_PAD = 10;

    //! Pyramid title (Dylan): one row if it fits the top chord, else two rows with
    //! row 1 <= row 2, each inside its own chord. Font steps down before ellipsizing.
    //! Returns the y just below the title block.
    function drawTitle(dc as Graphics.Dc, title as Lang.String, y as Lang.Number) as Lang.Number {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var fonts = [Graphics.FONT_TINY, Graphics.FONT_XTINY];
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        var k;
        for (k = 0; k < fonts.size(); k++) {
            var f = fonts[k] as Graphics.FontDefinition;
            var fh = dc.getFontHeight(f);
            var y2 = y + fh - 3;
            var c1 = RoundLayout.chordWidth(y, w, h) - 2 * ROW_PAD;
            var c2 = RoundLayout.chordWidth(y2, w, h) - 2 * ROW_PAD;
            if (dc.getTextWidthInPixels(title, f) <= c1) {
                dc.drawText(w / 2, y, f, title, Graphics.TEXT_JUSTIFY_CENTER);
                return y + fh;
            }
            var rows = pyramid(dc, title, f, c1, c2);
            if (rows != null) {
                dc.drawText(w / 2, y, f, rows[0] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(w / 2, y2, f, rows[1] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
                return y2 + fh;
            }
        }
        var ff = Graphics.FONT_XTINY;
        var cw = RoundLayout.chordWidth(y, w, h) - 2 * ROW_PAD;
        dc.drawText(w / 2, y, ff, ellipsize(dc, title, ff, cw), Graphics.TEXT_JUSTIFY_CENTER);
        return y + dc.getFontHeight(ff);
    }

    function pyramid(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition,
                     w1 as Lang.Number, w2 as Lang.Number) as Lang.Array or Null {
        var words = ContentLoader.splitWords(text);
        var best = null;
        var bestW1 = -1;
        var k;
        for (k = 1; k < words.size(); k++) {
            var a = "";
            var b = "";
            var i;
            for (i = 0; i < words.size(); i++) {
                if (i < k) {
                    a = a.length() == 0 ? words[i] as Lang.String : a + " " + words[i];
                } else {
                    b = b.length() == 0 ? words[i] as Lang.String : b + " " + words[i];
                }
            }
            var wa = dc.getTextWidthInPixels(a, font);
            var wb = dc.getTextWidthInPixels(b, font);
            if (wa <= w1 && wb <= w2 && wa <= wb && wa > bestW1) {
                best = [a, b];
                bestW1 = wa;
            }
        }
        return best;
    }

    function ellipsize(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition,
                       maxW as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(text, font) <= maxW) {
            return text;
        }
        var t = text;
        while (t.length() > 1 && dc.getTextWidthInPixels(t + "...", font) > maxW) {
            t = t.substring(0, t.length() - 1);
        }
        return t + "...";
    }

    // PERF cache: one list layout per (title, labels) — title pyramid, row geometry per
    // visible slot, and each label's fitted font/text per slot filled lazily. Scrolling a
    // list then costs only draw calls (no text measuring, no chord math per frame).
    var _cTitle as Lang.String or Null = null;
    var _cLabels as Lang.Array or Null = null;
    var _cTitleRows as Lang.Array = [] as Lang.Array; // [text, y, font] ...
    var _cTop as Lang.Number = 0;
    var _cRowH as Lang.Number = 0;
    var _cVis as Lang.Number = 1;
    var _cLeft as Lang.Array = [] as Lang.Array;
    var _cCw as Lang.Array = [] as Lang.Array;
    var _cFit as Lang.Array = [] as Lang.Array; // n * vis entries: null or [font, text]

    function layoutList(dc as Graphics.Dc, title as Lang.String, labels as Lang.Array) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        // Title: render once into a cheap list of draw ops by drawing to the real dc is not
        // possible here, so measure via drawTitle's logic into _cTitleRows.
        _cTitleRows = [] as Lang.Array;
        var y = titleLayout(dc, title, RoundLayout.edgeMargin(w, h)) + 4;
        var font = Graphics.FONT_SMALL;
        var rowH = dc.getFontHeight(font) + 4;
        // POKE: PICKLIST_BOTTOM — last row must sit where the chord is >= 62% of the width.
        var bottom = h - RoundLayout.edgeMargin(w, h);
        while (bottom > y + rowH && RoundLayout.chordWidth(bottom, w, h) < (w * 0.62).toNumber()) {
            bottom -= 2;
        }
        var vis = (bottom - y) / rowH;
        if (vis < 1) {
            vis = 1;
        }
        _cTop = y;
        _cRowH = rowH;
        _cVis = vis;
        _cLeft = [] as Lang.Array;
        _cCw = [] as Lang.Array;
        var r;
        for (r = 0; r < vis; r++) {
            var rowY = y + r * rowH;
            // Narrowest edge of the row decides fit.
            var edgeY = rowY < h / 2 ? rowY : rowY + rowH;
            _cCw.add(RoundLayout.chordWidth(edgeY, w, h));
            _cLeft.add(RoundLayout.chordLeft(edgeY, w, h));
        }
        _cFit = new [labels.size() * vis];
        _cTitle = title;
        _cLabels = labels;
    }

    function titleLayout(dc as Graphics.Dc, title as Lang.String, y as Lang.Number) as Lang.Number {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var fonts = [Graphics.FONT_TINY, Graphics.FONT_XTINY];
        var k;
        for (k = 0; k < fonts.size(); k++) {
            var f = fonts[k] as Graphics.FontDefinition;
            var fh = dc.getFontHeight(f);
            var y2 = y + fh - 3;
            var c1 = RoundLayout.chordWidth(y, w, h) - 2 * ROW_PAD;
            var c2 = RoundLayout.chordWidth(y2, w, h) - 2 * ROW_PAD;
            if (dc.getTextWidthInPixels(title, f) <= c1) {
                _cTitleRows.add([title, y, f]);
                return y + fh;
            }
            var rows = pyramid(dc, title, f, c1, c2);
            if (rows != null) {
                _cTitleRows.add([rows[0], y, f]);
                _cTitleRows.add([rows[1], y2, f]);
                return y2 + fh;
            }
        }
        var ff = Graphics.FONT_XTINY;
        var cw = RoundLayout.chordWidth(y, w, h) - 2 * ROW_PAD;
        _cTitleRows.add([ellipsize(dc, title, ff, cw), y, ff]);
        return y + dc.getFontHeight(ff);
    }

    function draw(dc as Graphics.Dc, title as Lang.String, labels as Lang.Array, focus as Lang.Number) as Void {
        Palette.applyBackground(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (_cLabels == null || _cLabels != labels || _cTitle == null || !(_cTitle as Lang.String).equals(title)) {
            layoutList(dc, title, labels);
        }
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        var t;
        for (t = 0; t < _cTitleRows.size(); t++) {
            var tr = _cTitleRows[t] as Lang.Array;
            dc.drawText(w / 2, tr[1] as Lang.Number, tr[2] as Graphics.FontDefinition, tr[0] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
        var y = _cTop;
        var rowH = _cRowH;
        var vis = _cVis;
        var n = labels.size();
        // Focus rides the middle (widest) rows; near the end the list scrolls past its
        // last item (blank rows below) instead of pushing the pill onto the narrow edge.
        var start = focus - (vis - 1) / 2;
        if (start < 0) {
            start = 0;
        }
        lastTop = y;
        lastRowH = rowH;
        lastStart = start;
        lastVis = vis;
        var r;
        for (r = 0; r < vis && start + r < n; r++) {
            var i = start + r;
            var rowY = y + r * rowH;
            var cw = _cCw[r] as Lang.Number;
            var left = _cLeft[r] as Lang.Number;
            var fit = _cFit[i * vis + r];
            if (fit == null) {
                var room = cw - 2 * ROW_PAD;
                var label = labels[i] as Lang.String;
                var fonts = [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
                var f = Graphics.FONT_XTINY;
                var k;
                for (k = 0; k < fonts.size(); k++) {
                    if (dc.getTextWidthInPixels(label, fonts[k] as Graphics.FontDefinition) <= room) {
                        f = fonts[k] as Graphics.FontDefinition;
                        break;
                    }
                }
                fit = [f, ellipsize(dc, label, f, room), dc.getFontHeight(f)]; // ellipsis = last resort only
                _cFit[i * vis + r] = fit;
            }
            var ff = fit[0] as Graphics.FontDefinition;
            if (i == focus) {
                dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_FG);
                dc.fillRectangle(left + ROW_PAD / 2, rowY, cw - ROW_PAD, rowH - 2);
                dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(w / 2, rowY + (rowH - 2 - (fit[2] as Lang.Number)) / 2, ff, fit[1] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        if (start > 0) {
            dc.fillPolygon([[w / 2 - 5, y - 1], [w / 2 + 5, y - 1], [w / 2, y - 5]]);
        }
        if (start + vis < n) {
            var by = y + vis * rowH;
            dc.fillPolygon([[w / 2 - 5, by], [w / 2 + 5, by], [w / 2, by + 4]]);
        }
    }

    //! Open a book like Flipper: single-chapter books skip the 1-cell chapter grid.
    function openBook(bi as Lang.Number) as Void {
        AppState.selectedBook = bi;
        AppState.selectedChapter = LastReadApp.chapterFor(bi); // last-read chapter, else 1
        if (Books.chapterCount(bi) == 1) {
            ReaderView.openFor(bi, 1);
            return;
        }
        WatchUi.pushView(new ChapterGridView(), new ChapterGridDelegate(), WatchUi.SLIDE_LEFT);
    }
}

class PickListView extends WatchUi.View {
    var title as Lang.String;
    var labels as Lang.Array;
    var focus as Lang.Number = 0;

    function initialize(title as Lang.String, labels as Lang.Array) {
        View.initialize();
        me.title = title;
        me.labels = labels;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        PickList.draw(dc, title, labels, focus);
    }
}

//! kind: 0 = book list (books[] -> openBook), 1 = A–Z filter (-> filtered book list)
class PickListDelegate extends WatchUi.BehaviorDelegate {
    var _view as PickListView;
    var _kind as Lang.Number;
    var _books as Lang.Array;

    function initialize(view as PickListView, kind as Lang.Number, books as Lang.Array) {
        BehaviorDelegate.initialize();
        _view = view;
        _kind = kind;
        _books = books;
    }

    function onNextPage() as Lang.Boolean {
        var n = _view.labels.size();
        if (n > 0) {
            _view.focus = (_view.focus + 1) % n;
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        var n = _view.labels.size();
        if (n > 0) {
            _view.focus = (_view.focus + n - 1) % n;
        }
        WatchUi.requestUpdate();
        return true;
    }

    // TAP FIX: on touch watches a screen tap is ALSO mapped to the onSelect behavior
    // (before onTap), which opened the highlighted row instead of the tapped one.
    // onSelect therefore never acts: button Enter arrives via onKey, taps via onTap.
    function onSelect() as Lang.Boolean {
        return false;
    }

    function onKey(evt as WatchUi.KeyEvent) as Lang.Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            return activate();
        }
        return false;
    }

    function activate() as Lang.Boolean {
        if (_view.labels.size() == 0) {
            return true;
        }
        if (_kind == 1) {
            var books = PickList.booksForFilter(_view.focus);
            var title = _view.focus == 0 ? "All books" : "Books: " + PickList.FILTER_LABELS[_view.focus];
            var v = new PickListView(title, PickList.bookLabels(books));
            WatchUi.pushView(v, new PickListDelegate(v, 0, books), WatchUi.SLIDE_LEFT);
            return true;
        }
        PickList.openBook(_books[_view.focus] as Lang.Number);
        return true;
    }

    //! Tap: hit-test the rows PickList.draw just laid out; open the TAPPED row.
    function onTap(evt as WatchUi.ClickEvent) as Lang.Boolean {
        var idx = PickList.indexAtY(evt.getCoordinates()[1], _view.labels.size());
        if (idx >= 0) {
            _view.focus = idx;
            activate();
        }
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            return onNextPage();
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            return onPreviousPage();
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            return onBack();
        }
        return false;
    }
}

//! Home (book list) Menu2 — Flipper home: Left = Collection(Bookmarks), Right = Testament, Right again = Filter.
class HomeMenu2Delegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    static function open() as Void {
        var menu = new ThemedMenu("Browse");
        menu.addItem(new ThemedMenuItem("Bookmarks", null, :bookmarks));
        menu.addItem(new ThemedMenuItem("By Testament", null, :testament));
        menu.addItem(new ThemedMenuItem("By letter", "All, A-Z, 1-3", :letter));
        menu.addItem(new ThemedMenuItem("All books", null, :all));
        menu.addItem(new ThemedMenuItem("Theme: " + Palette.themeLabel(), "Dark / Light", :theme));
        WatchUi.pushView(menu, new HomeMenu2Delegate(), WatchUi.SLIDE_UP);
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (id == :bookmarks) {
            WatchUi.pushView(new BookmarksView(), new BookmarksDelegate(), WatchUi.SLIDE_UP);
        } else if (id == :testament) {
            WatchUi.pushView(new TestamentListView(), new TestamentListDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :letter) {
            var v = new PickListView("Filter", PickList.FILTER_LABELS);
            WatchUi.pushView(v, new PickListDelegate(v, 1, [] as Lang.Array), WatchUi.SLIDE_LEFT);
        } else if (id == :theme) {
            Palette.toggleTheme();
            WatchUi.requestUpdate();
        } else if (id == :all) {
            var books = PickList.booksForFilter(0);
            var v2 = new PickListView("All books", PickList.bookLabels(books));
            WatchUi.pushView(v2, new PickListDelegate(v2, 0, books), WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
