using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

class ChapterGridView extends WatchUi.View {
    var grid as SnakeGrid.Model;
    var holdTimer as Timer.Timer or Null = null;
    var holding as Lang.Boolean = false;

    function initialize() {
        View.initialize();
        var settings = System.getDeviceSettings();
        var w = settings.screenWidth;
        var h = settings.screenHeight;
        var cols = SnakeGrid.columnsForDisplayWidth(w);
        var rows = SnakeGrid.visibleRowsForHeight(h);
        var n = Books.chapterCount(AppState.selectedBook);
        grid = new SnakeGrid.Model(n, cols, rows);
        grid.setFocusIndex(AppState.selectedChapter - 1);
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var inset = (w < h ? w : h) / 10;
        var title = Books.name(AppState.selectedBook);
        dc.drawText(w / 2, inset, Graphics.FONT_TINY, title, Graphics.TEXT_JUSTIFY_CENTER);
        var top = inset + dc.getFontHeight(Graphics.FONT_TINY) + 6;
        dc.drawLine(inset, top - 4, w - inset, top - 4);

        var cellW = (w - 2 * inset) / grid.columns;
        var cellH = (h - top - inset) / grid.visibleRows;
        if (cellH < 18) {
            cellH = 18;
        }
        var r;
        var c;
        for (r = 0; r < grid.visibleRows; r++) {
            var row = grid.startRow + r;
            for (c = 0; c < grid.columns; c++) {
                var idx = grid.indexAt(row, c);
                if (idx >= grid.itemCount) {
                    break;
                }
                var ch = idx + 1;
                var x = inset + c * cellW;
                var y = top + r * cellH;
                var label = ch.toString();
                if (idx == grid.focusIndex) {
                    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                    dc.fillRectangle(x + 1, y + 1, cellW - 2, cellH - 2);
                    dc.drawText(x + cellW / 2, y + cellH / 2 - dc.getFontHeight(Graphics.FONT_SMALL) / 2,
                        Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);
                    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
                } else {
                    dc.drawText(x + cellW / 2, y + cellH / 2 - dc.getFontHeight(Graphics.FONT_SMALL) / 2,
                        Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);
                }
            }
        }
    }
}

class ChapterGridDelegate extends WatchUi.BehaviorDelegate {
    var _holdTimer as Timer.Timer or Null = null;

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function gridView() as ChapterGridView {
        return WatchUi.getCurrentView()[0] as ChapterGridView;
    }

    function onNextPage() as Lang.Boolean {
        gridView().grid.next();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        gridView().grid.prev();
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Lang.Boolean {
        var g = gridView().grid;
        AppState.selectedChapter = g.focusedChapter();
        ReaderView.openFor(AppState.selectedBook, AppState.selectedChapter);
        return true;
    }

    //! Hold Select = bookmark chapter (verse=0).
    function onKey(evt) as Lang.Boolean {
        // POKE: measure hold with onKeyPressed/Released timing vs onHold for Enduro 3 Select.
        return false;
    }

    function onHold(evt) as Lang.Boolean {
        var g = gridView().grid;
        var ch = g.focusedChapter();
        var result = Bookmarks.toggle(AppState.selectedBook, ch, 0);
        // Feedback via push toast view would go here; spike uses System.println.
        System.println("bookmark chapter " + result);
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Lang.Boolean {
        AppState.selectedChapter = gridView().grid.focusedChapter();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
