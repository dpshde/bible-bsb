using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class BookListView extends WatchUi.View {
    var focus as Lang.Number = 0; // index into Books.SPIKE_BOOK_INDEXES

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        // POKE: apply round safe inset % from SPEC after Enduro 3 screenshots.
        var inset = (w < h ? w : h) / 10;
        var y = inset + 4;
        dc.drawText(w / 2, y, Graphics.FONT_TINY, "Bible BSB", Graphics.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(Graphics.FONT_TINY) + 4;
        dc.drawLine(inset, y, w - inset, y);
        y += 6;
        var i;
        for (i = 0; i < Books.SPIKE_BOOK_INDEXES.size(); i++) {
            var bi = Books.SPIKE_BOOK_INDEXES[i];
            var label = Books.name(bi);
            if (i == focus) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(inset, y - 2, w - 2 * inset, dc.getFontHeight(Graphics.FONT_SMALL) + 4);
                dc.drawText(inset + 6, y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
            } else {
                dc.drawText(inset + 6, y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);
            }
            y += dc.getFontHeight(Graphics.FONT_SMALL) + 6;
        }
        dc.drawText(w / 2, h - inset, Graphics.FONT_XTINY, "Menu=Bookmarks", Graphics.TEXT_JUSTIFY_CENTER);
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
        var v = view();
        v.focus = (v.focus + 1) % Books.SPIKE_BOOK_INDEXES.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        var v = view();
        v.focus = (v.focus + Books.SPIKE_BOOK_INDEXES.size() - 1) % Books.SPIKE_BOOK_INDEXES.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Lang.Boolean {
        var v = view();
        AppState.selectedBook = Books.SPIKE_BOOK_INDEXES[v.focus];
        AppState.selectedChapter = 1;
        if (AppState.selectedBook == 42) {
            AppState.selectedChapter = 3; // jump into bundled John 3 for thin slice
        } else if (AppState.selectedBook == 38) {
            AppState.selectedChapter = 4;
        }
        WatchUi.pushView(new ChapterGridView(), new ChapterGridDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

    function onMenu() as Lang.Boolean {
        WatchUi.pushView(new BookmarksView(), new BookmarksDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
