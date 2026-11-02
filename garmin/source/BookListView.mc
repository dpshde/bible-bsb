using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class BookListView extends WatchUi.View {
    var focus as Lang.Number = 0; // index into Books.SPIKE_BOOK_INDEXES

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var titleFont = Graphics.FONT_TINY;
        var rowFont = Graphics.FONT_SMALL;
        var y = RoundLayout.edgeMargin(w, h);
        RoundLayout.drawCenteredInChord(dc, y, "Bible BSB", titleFont);
        y += dc.getFontHeight(titleFont) + 4;
        var ruleLeft = RoundLayout.chordLeft(y, w, h);
        dc.drawLine(ruleLeft, y, ruleLeft + RoundLayout.chordWidth(y, w, h), y);
        y += 8;

        var rowH = dc.getFontHeight(rowFont) + 8;
        var i;
        for (i = 0; i < Books.SPIKE_BOOK_INDEXES.size(); i++) {
            var bi = Books.SPIKE_BOOK_INDEXES[i];
            var label = Books.name(bi);
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

        // Footer hint: sit on a chord well above the bottom bevel (was clipped).
        var hint = "Menu = Bookmarks";
        var hintFont = Graphics.FONT_XTINY;
        var hintH = dc.getFontHeight(hintFont);
        var hintY = h - RoundLayout.edgeMargin(w, h) - hintH - 4;
        // Ensure hintY chord is wide enough; nudge up if near the edge.
        if (RoundLayout.chordWidth(hintY + hintH / 2, w, h) < dc.getTextWidthInPixels(hint, hintFont) + 8) {
            hintY -= hintH;
        }
        RoundLayout.drawCenteredInChord(dc, hintY, hint, hintFont);
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
            AppState.selectedChapter = 3;
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
