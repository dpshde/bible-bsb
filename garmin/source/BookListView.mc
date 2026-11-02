using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class BookListView extends WatchUi.View {
    var focus as Lang.Number = 0; // index into Books.SPIKE_BOOK_INDEXES
    // Hit-test cache from last onUpdate
    var _rowTop as Lang.Number = 0;
    var _rowH as Lang.Number = 0;
    var _rowCount as Lang.Number = 0;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Palette.applyBackground(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        var titleFont = Graphics.FONT_TINY;
        var rowFont = Graphics.FONT_SMALL;
        var y = RoundLayout.edgeMargin(w, h);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        RoundLayout.drawCenteredInChord(dc, y, "Bible BSB", titleFont);
        y += dc.getFontHeight(titleFont) + 4;
        var ruleLeft = RoundLayout.chordLeft(y, w, h);
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ruleLeft, y, ruleLeft + RoundLayout.chordWidth(y, w, h), y);
        y += 8;

        var rowH = dc.getFontHeight(rowFont) + 8;
        _rowTop = y;
        _rowH = rowH;
        _rowCount = Books.SPIKE_BOOK_INDEXES.size();

        var i;
        for (i = 0; i < _rowCount; i++) {
            var bi = Books.SPIKE_BOOK_INDEXES[i];
            var label = Books.name(bi);
            var midY = y + rowH / 2;
            var left = RoundLayout.chordLeft(midY, w, h);
            var cw = RoundLayout.chordWidth(midY, w, h);
            if (i == focus) {
                dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_FG);
                dc.fillRectangle(left, y, cw, rowH - 2);
                dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y + 3, rowFont, label, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y + 3, rowFont, label, Graphics.TEXT_JUSTIFY_CENTER);
            }
            y += rowH;
        }

        var hint = "Menu = Bookmarks";
        var hintFont = Graphics.FONT_XTINY;
        var hintH = dc.getFontHeight(hintFont);
        var hintY = h - RoundLayout.edgeMargin(w, h) - hintH - 4;
        if (RoundLayout.chordWidth(hintY + hintH / 2, w, h) < dc.getTextWidthInPixels(hint, hintFont) + 8) {
            hintY -= hintH;
        }
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        RoundLayout.drawCenteredInChord(dc, hintY, hint, hintFont);
    }

    function rowAtY(y as Lang.Number) as Lang.Number {
        if (_rowH <= 0) {
            return -1;
        }
        var idx = ((y - _rowTop) / _rowH).toNumber();
        if (idx < 0 || idx >= _rowCount) {
            return -1;
        }
        return idx;
    }

    function openFocusedBook() as Void {
        AppState.selectedBook = Books.SPIKE_BOOK_INDEXES[focus];
        AppState.selectedChapter = 1;
        if (AppState.selectedBook == 42) {
            AppState.selectedChapter = 3;
        } else if (AppState.selectedBook == 38) {
            AppState.selectedChapter = 4;
        }
        WatchUi.pushView(new ChapterGridView(), new ChapterGridDelegate(), WatchUi.SLIDE_LEFT);
    }
}

class BookListDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function view() as BookListView {
        return WatchUi.getCurrentView()[0] as BookListView;
    }

    function onNextPage() as Lang.Boolean {
        if (TouchGuard.consumePage()) {
            return true;
        }
        var v = view();
        v.focus = (v.focus + 1) % Books.SPIKE_BOOK_INDEXES.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        if (TouchGuard.consumePage()) {
            return true;
        }
        var v = view();
        v.focus = (v.focus + Books.SPIKE_BOOK_INDEXES.size() - 1) % Books.SPIKE_BOOK_INDEXES.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Lang.Boolean {
        if (TouchGuard.consumeSelect()) {
            return true;
        }
        view().openFocusedBook();
        return true;
    }

    function onTap(evt) as Lang.Boolean {
        var coords = evt.getCoordinates();
        var v = view();
        var idx = v.rowAtY(coords[1]);
        if (idx >= 0) {
            v.focus = idx;
            TouchGuard.markSelect();
            v.openFocusedBook();
            return true;
        }
        return false;
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            TouchGuard.markPage();
            var v = view();
            v.focus = (v.focus + 1) % Books.SPIKE_BOOK_INDEXES.size();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            TouchGuard.markPage();
            var v2 = view();
            v2.focus = (v2.focus + Books.SPIKE_BOOK_INDEXES.size() - 1) % Books.SPIKE_BOOK_INDEXES.size();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            TouchGuard.markBack();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onMenu() as Lang.Boolean {
        WatchUi.pushView(new BookmarksView(), new BookmarksDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onBack() as Lang.Boolean {
        if (TouchGuard.consumeBack()) {
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
