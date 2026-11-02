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

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var inset = (w < h ? w : h) / 10;
        dc.drawText(w / 2, inset, Graphics.FONT_TINY, "Bookmarks", Graphics.TEXT_JUSTIFY_CENTER);
        var y = inset + dc.getFontHeight(Graphics.FONT_TINY) + 6;
        dc.drawLine(inset, y - 4, w - inset, y - 4);
        if (items.size() == 0) {
            dc.drawText(w / 2, h / 2, Graphics.FONT_SMALL, "No bookmarks", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var i;
        for (i = 0; i < items.size(); i++) {
            var label = Bookmarks.formatLabel(items[i] as Lang.Number);
            if (i == focus) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(inset, y - 2, w - 2 * inset, dc.getFontHeight(Graphics.FONT_SMALL) + 4);
                dc.drawText(inset + 4, y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
            } else {
                dc.drawText(inset + 4, y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);
            }
            y += dc.getFontHeight(Graphics.FONT_SMALL) + 6;
            if (y > h - inset) {
                break;
            }
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
            // deferred snap once lines built
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
