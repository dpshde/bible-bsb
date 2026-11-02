using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class BookmarksView extends WatchUi.View {
    var focus as Lang.Number = 0;
    var items as Lang.Array = [];

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
            return;
        }

        var rowH = dc.getFontHeight(rowFont) + 8;
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
}

class BookmarksDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function bv() as BookmarksView {
        return WatchUi.getCurrentView()[0] as BookmarksView;
    }

    function onNextPage() as Lang.Boolean {
        var v = bv();
        if (v.items.size() == 0) {
            return true;
        }
        v.focus = (v.focus + 1) % v.items.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        var v = bv();
        if (v.items.size() == 0) {
            return true;
        }
        v.focus = (v.focus + v.items.size() - 1) % v.items.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Lang.Boolean {
        var v = bv();
        if (v.items.size() == 0) {
            return true;
        }
        var id = v.items[v.focus] as Lang.Number;
        var book = Bookmarks.unpackBook(id);
        var chapter = Bookmarks.unpackChapter(id);
        var verse = Bookmarks.unpackVerse(id);
        ReaderView.openFor(book, chapter);
        // POKE: after open, scrollOffset snap to verse if verse!=0.
        if (verse != 0) {
        }
        return true;
    }

    function onHold(evt) as Lang.Boolean {
        var v = bv();
        if (v.items.size() == 0) {
            return true;
        }
        var id = v.items[v.focus] as Lang.Number;
        Bookmarks.toggle(Bookmarks.unpackBook(id), Bookmarks.unpackChapter(id), Bookmarks.unpackVerse(id));
        v.items = Bookmarks.load();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
