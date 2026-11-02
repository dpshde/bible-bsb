using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

class ChapterGridView extends WatchUi.View {
    var grid as SnakeGrid.Model;
    var holdTimer as Timer.Timer or Null = null;
    var holding as Lang.Boolean = false;
    var _gridBook as Lang.Number = -1;
    // Hit-test cache
    var _gridTop as Lang.Number = 0;
    var _cellH as Lang.Number = 0;
    var _screenW as Lang.Number = 0;
    var _screenH as Lang.Number = 0;

    function initialize() {
        View.initialize();
        rebuildGridFromState();
    }

    //! Rebuild snake model from AppState — fixes Back-from-continuation leaving
    //! Malachi's grid while selectedBook is Matthew (VALIDATION Genes 1:1 bug).
    function rebuildGridFromState() as Void {
        var settings = System.getDeviceSettings();
        var w = settings.screenWidth;
        var h = settings.screenHeight;
        var cols = SnakeGrid.columnsForDisplayWidth(w);
        var rows = SnakeGrid.visibleRowsForHeight(h);
        var n = Books.chapterCount(AppState.selectedBook);
        grid = new SnakeGrid.Model(n, cols, rows);
        var focusIdx = AppState.selectedChapter - 1;
        if (focusIdx < 0) {
            focusIdx = 0;
        }
        if (focusIdx >= n) {
            focusIdx = n > 0 ? n - 1 : 0;
        }
        grid.setFocusIndex(focusIdx);
        _gridBook = AppState.selectedBook;
    }

    function onShow() as Void {
        // Spec: Back to grid focuses the continued chapter's book.
        if (_gridBook != AppState.selectedBook
            || grid.focusedChapter() != AppState.selectedChapter
            || grid.itemCount != Books.chapterCount(AppState.selectedBook)) {
            rebuildGridFromState();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Palette.applyBackground(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        _screenW = w;
        _screenH = h;
        Fonts.ensureLoaded();
        var titleY = RoundLayout.edgeMargin(w, h);
        // Chapter header: letterspaced small caps gold (never deep blue/green).
        Fonts.drawLetterspacedCaps(dc, w / 2, titleY, Books.name(AppState.selectedBook), Palette.GOLD);

        var top = titleY + dc.getFontHeight(Fonts.headerCaps) + 6;
        var ruleLeft = RoundLayout.chordLeft(top - 4, w, h);
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ruleLeft, top - 4, ruleLeft + RoundLayout.chordWidth(top - 4, w, h), top - 4);

        var bottom = h - RoundLayout.edgeMargin(w, h);
        var cellH = (bottom - top) / grid.visibleRows;
        if (cellH < 18) {
            cellH = 18;
        }
        _gridTop = top;
        _cellH = cellH;

        var r;
        var c;
        for (r = 0; r < grid.visibleRows; r++) {
            var row = grid.startRow + r;
            var rowMidY = top + r * cellH + cellH / 2;
            var rowLeft = RoundLayout.chordLeft(rowMidY, w, h);
            var rowW = RoundLayout.chordWidth(rowMidY, w, h);
            var cellW = rowW / grid.columns;
            for (c = 0; c < grid.columns; c++) {
                var idx = grid.indexAt(row, c);
                if (idx >= grid.itemCount) {
                    break;
                }
                var ch = idx + 1;
                var x = rowLeft + c * cellW;
                var y = top + r * cellH;
                var label = ch.toString();
                if (idx == grid.focusIndex) {
                    dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_FG);
                    dc.fillRectangle(x + 1, y + 1, cellW - 2, cellH - 2);
                    dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(x + cellW / 2, y + cellH / 2 - dc.getFontHeight(Graphics.FONT_SMALL) / 2,
                        Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);
                } else {
                    dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(x + cellW / 2, y + cellH / 2 - dc.getFontHeight(Graphics.FONT_SMALL) / 2,
                        Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);
                }
            }
        }
    }

    //! Map screen coords to chapter index, or -1.
    function chapterAt(x as Lang.Number, y as Lang.Number) as Lang.Number {
        if (_cellH <= 0) {
            return -1;
        }
        var displayRow = ((y - _gridTop) / _cellH).toNumber();
        if (displayRow < 0 || displayRow >= grid.visibleRows) {
            return -1;
        }
        var row = grid.startRow + displayRow;
        var rowMidY = _gridTop + displayRow * _cellH + _cellH / 2;
        var rowLeft = RoundLayout.chordLeft(rowMidY, _screenW, _screenH);
        var rowW = RoundLayout.chordWidth(rowMidY, _screenW, _screenH);
        if (x < rowLeft || x > rowLeft + rowW) {
            return -1;
        }
        var cellW = rowW / grid.columns;
        var col = ((x - rowLeft) / cellW).toNumber();
        if (col < 0 || col >= grid.columns) {
            return -1;
        }
        var idx = grid.indexAt(row, col);
        if (idx < 0 || idx >= grid.itemCount) {
            return -1;
        }
        return idx;
    }

    function openChapterIndex(idx as Lang.Number) as Void {
        grid.setFocusIndex(idx);
        AppState.selectedBook = _gridBook >= 0 ? _gridBook : AppState.selectedBook;
        AppState.selectedChapter = grid.focusedChapter();
        ReaderView.openFor(AppState.selectedBook, AppState.selectedChapter);
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
        if (TouchGuard.consumePage()) {
            return true;
        }
        gridView().grid.next();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        if (TouchGuard.consumePage()) {
            return true;
        }
        gridView().grid.prev();
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Lang.Boolean {
        if (TouchGuard.consumeSelect()) {
            return true;
        }
        var v = gridView();
        v.openChapterIndex(v.grid.focusIndex);
        return true;
    }

    function onKey(evt) as Lang.Boolean {
        // POKE: measure hold with onKeyPressed/Released timing vs onHold for Enduro 3 Select.
        return false;
    }

    function onHold(evt) as Lang.Boolean {
        TouchGuard.markSelect();
        var coords = evt.getCoordinates();
        var v = gridView();
        var idx = v.chapterAt(coords[0], coords[1]);
        if (idx >= 0) {
            v.grid.setFocusIndex(idx);
        }
        var ch = v.grid.focusedChapter();
        var book = v._gridBook >= 0 ? v._gridBook : AppState.selectedBook;
        var result = Bookmarks.toggle(book, ch, 0);
        System.println("bookmark chapter " + result);
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt) as Lang.Boolean {
        var coords = evt.getCoordinates();
        var v = gridView();
        var idx = v.chapterAt(coords[0], coords[1]);
        if (idx >= 0) {
            TouchGuard.markSelect();
            v.openChapterIndex(idx);
            return true;
        }
        return false;
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        // POKE: swipe moves one snake step; try whole-row (±columns) if it feels slow on Psalms.
        if (dir == WatchUi.SWIPE_UP) {
            TouchGuard.markPage();
            gridView().grid.next();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            TouchGuard.markPage();
            gridView().grid.prev();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            TouchGuard.markBack();
            AppState.selectedChapter = gridView().grid.focusedChapter();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onBack() as Lang.Boolean {
        if (TouchGuard.consumeBack()) {
            return true;
        }
        AppState.selectedChapter = gridView().grid.focusedChapter();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
