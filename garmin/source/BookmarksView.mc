using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class BookmarksView extends WatchUi.View {
    var focus as Lang.Number = 0;
    var items as Lang.Array = [];
    var _rowTop as Lang.Number = 0;
    var _rowH as Lang.Number = 0;

    function initialize() {
        View.initialize();
        items = Bookmarks.load();
    }

    function onShow() as Void {
        items = Bookmarks.load();
        if (focus >= items.size()) {
            focus = items.size() > 0 ? items.size() - 1 : 0;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var titleFont = Graphics.FONT_TINY;
        var rowFont = Graphics.FONT_SMALL;
        var y = RoundLayout.edgeMargin(w, h);
        RoundLayout.drawCenteredInChord(dc, y, "Bookmarks", titleFont);
        y += dc.getFontHeight(titleFont) + 6;
        var ruleLeft = RoundLayout.chordLeft(y - 4, w, h);
        dc.drawLine(ruleLeft, y - 4, ruleLeft + RoundLayout.chordWidth(y - 4, w, h), y - 4);

        if (items.size() == 0) {
            RoundLayout.drawCenteredInChord(dc, h / 2, "No bookmarks", Graphics.FONT_SMALL);
            _rowTop = 0;
            _rowH = 0;
            return;
        }

        var rowH = dc.getFontHeight(rowFont) + 8;
        _rowTop = y;
        _rowH = rowH;
        var bottom = h - RoundLayout.edgeMargin(w, h);
        var i;
        for (i = 0; i < items.size(); i++) {
            if (y + rowH > bottom) {
                break;
            }
            var label = Bookmarks.formatLabel(items[i] as Lang.Number);
            var midY = y + rowH / 2;
            var left = RoundLayout.chordLeft(midY, w, h);
            var cw = RoundLayout.chordWidth(midY, w, h);
            if (i == focus) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(left, y, cw, rowH - 2);
                dc.drawText(w / 2, y + 3, rowFont, label, Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
            } else {
                dc.drawText(w / 2, y + 3, rowFont, label, Graphics.TEXT_JUSTIFY_CENTER);
            }
            y += rowH;
        }
    }

    function rowAtY(y as Lang.Number) as Lang.Number {
        if (_rowH <= 0 || items.size() == 0) {
            return -1;
        }
        var idx = ((y - _rowTop) / _rowH).toNumber();
        if (idx < 0 || idx >= items.size()) {
            return -1;
        }
        return idx;
    }

    function openFocused() as Void {
        if (items.size() == 0) {
            return;
        }
        var id = items[focus] as Lang.Number;
        var book = Bookmarks.unpackBook(id);
        var chapter = Bookmarks.unpackChapter(id);
        ReaderView.openFor(book, chapter);
        // POKE: snap scrollOffset to verse if verse!=0 after open.
    }
}

class BookmarksDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function bv() as BookmarksView {
        return WatchUi.getCurrentView()[0] as BookmarksView;
    }

    function onNextPage() as Lang.Boolean {
        if (TouchGuard.consumePage()) {
            return true;
        }
        var v = bv();
        if (v.items.size() == 0) {
            return true;
        }
        v.focus = (v.focus + 1) % v.items.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        if (TouchGuard.consumePage()) {
            return true;
        }
        var v = bv();
        if (v.items.size() == 0) {
            return true;
        }
        v.focus = (v.focus + v.items.size() - 1) % v.items.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Lang.Boolean {
        if (TouchGuard.consumeSelect()) {
            return true;
        }
        bv().openFocused();
        return true;
    }

    function onTap(evt) as Lang.Boolean {
        var coords = evt.getCoordinates();
        var v = bv();
        var idx = v.rowAtY(coords[1]);
        if (idx >= 0) {
            v.focus = idx;
            TouchGuard.markSelect();
            v.openFocused();
            return true;
        }
        return false;
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        var v = bv();
        if (dir == WatchUi.SWIPE_UP) {
            TouchGuard.markPage();
            if (v.items.size() > 0) {
                v.focus = (v.focus + 1) % v.items.size();
                WatchUi.requestUpdate();
            }
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            TouchGuard.markPage();
            if (v.items.size() > 0) {
                v.focus = (v.focus + v.items.size() - 1) % v.items.size();
                WatchUi.requestUpdate();
            }
            return true;
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            TouchGuard.markBack();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }
        return false;
    }

    function onHold(evt) as Lang.Boolean {
        TouchGuard.markSelect();
        var v = bv();
        if (v.items.size() == 0) {
            return true;
        }
        var coords = evt.getCoordinates();
        var idx = v.rowAtY(coords[1]);
        if (idx >= 0) {
            v.focus = idx;
        }
        var id = v.items[v.focus] as Lang.Number;
        Bookmarks.toggle(Bookmarks.unpackBook(id), Bookmarks.unpackChapter(id), Bookmarks.unpackVerse(id));
        v.items = Bookmarks.load();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Lang.Boolean {
        if (TouchGuard.consumeBack()) {
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
