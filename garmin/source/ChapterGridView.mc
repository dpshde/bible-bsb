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
    // Chord-reflow: first chapter index shown + per-visible-row start/cap (hit-test cache).
    var _firstIdx as Lang.Number = 0;
    var _rowStart as Lang.Array = [] as Lang.Array;
    var _rowCap as Lang.Array = [] as Lang.Array;

    function initialize() {
        View.initialize();
        grid = new SnakeGrid.Model(1, 1, 1);
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
        _firstIdx = 0;
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
        var t0 = Perf.start();
        onUpdateImpl(dc);
        Perf.end("grid", t0);
    }

    // PERF caches: per-book headings (1 resource), per-chapter subtitle split, per-top layout,
    // per-book label strings. Grid key presses then cost draw calls only.
    var _headsBook as Lang.Number = -1;
    var _heads as Lang.Array or Null = null;
    var _subKey as Lang.Number = -1;
    var _subParts as Lang.Array or Null = null;
    var _layTop as Lang.Number = -1;
    var _layCount as Lang.Number = -1;
    var _caps as Lang.Array = [] as Lang.Array;
    var _rowLeftA as Lang.Array = [] as Lang.Array;
    var _cellWA as Lang.Array = [] as Lang.Array;
    var _capTotal as Lang.Number = 0;
    var _labels as Lang.Array = [] as Lang.Array;

    function onUpdateImpl(dc as Graphics.Dc) as Void {
        Palette.applyBackground(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        _screenW = w;
        _screenH = h;
        var titleFont = Graphics.FONT_TINY;
        var titleY = RoundLayout.edgeMargin(w, h);
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        RoundLayout.drawCenteredInChord(dc, titleY, Books.name(AppState.selectedBook), titleFont);

        // First section heading of the focused chapter as subtitle when bundled.
        var subY = titleY + dc.getFontHeight(titleFont) + 1;
        var focusCh = grid.focusedChapter();
        var sf = Graphics.FONT_XTINY;
        var sh = dc.getFontHeight(sf);
        if (_subKey != AppState.selectedBook * 1000 + focusCh) {
            _subKey = AppState.selectedBook * 1000 + focusCh;
            _subParts = null;
            var firstSec = firstSectionTitle(AppState.selectedBook, focusCh);
            if (firstSec != null) {
                var st = firstSec as Lang.String;
                // POKE: GRID_SUBTITLE_WRAP — never clip: one line if it fits the chord, else pyramid two lines.
                var c1 = RoundLayout.chordWidth(subY, w, h) - 12;
                if (dc.getTextWidthInPixels(st, sf) <= c1) {
                    _subParts = [st];
                } else {
                    var c2 = RoundLayout.chordWidth(subY + sh - 2, w, h) - 12;
                    var parts = RoundLayout.pyramidSplit(dc, st, sf, c1, c2);
                    if (parts == null) {
                        parts = RoundLayout.pyramidSplitEllipsize(dc, st, sf, c1, c2);
                    }
                    _subParts = parts;
                }
            }
        }
        if (_subParts != null) {
            var sp = _subParts as Lang.Array;
            dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, subY, sf, sp[0] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
            if (sp.size() > 1) {
                dc.drawText(w / 2, subY + sh - 2, sf, sp[1] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
                subY += 2 * sh;
            } else {
                subY += sh + 2;
            }
        }

        var top = subY + 4;
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

        if (_layTop != top || _layCount != grid.itemCount) {
            computeLayout(dc, top, cellH, w, h);
        }
        var caps = _caps;
        var total = _capTotal;
        var r;
        var step = caps[0] as Lang.Number;
        if (_firstIdx >= grid.itemCount) {
            _firstIdx = 0;
        }
        while (grid.focusIndex < _firstIdx) {
            _firstIdx -= step;
            if (_firstIdx < 0) {
                _firstIdx = 0;
            }
        }
        while (grid.focusIndex >= _firstIdx + total) {
            _firstIdx += step;
        }
        _rowStart = [] as Lang.Array;
        _rowCap = caps;
        var idx = _firstIdx;
        var c;
        var smallH = dc.getFontHeight(Graphics.FONT_SMALL);
        for (r = 0; r < grid.visibleRows; r++) {
            _rowStart.add(idx);
            var cap2 = caps[r] as Lang.Number;
            var cellW = _cellWA[r] as Lang.Number;
            var rowLeft = _rowLeftA[r] as Lang.Number;
            for (c = 0; c < cap2; c++) {
                if (idx >= grid.itemCount) {
                    break;
                }
                var ch = idx + 1;
                var x = rowLeft + c * cellW;
                var y = top + r * cellH;
                var label = _labels[idx] as Lang.String;
                var ty = y + cellH / 2 - smallH / 2;
                if (idx == grid.focusIndex) {
                    dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_FG);
                    dc.fillRectangle(x + 1, y + 1, cellW - 2, cellH - 2);
                    dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
                }
                dc.drawText(x + cellW / 2, ty, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);
                idx++;
            }
        }
    }

    //! PERF: per-row capacity / left / cell width for this grid top, computed once (not per frame).
    function computeLayout(dc as Graphics.Dc, top as Lang.Number, cellH as Lang.Number,
                           w as Lang.Number, h as Lang.Number) as Void {
        // Per-row capacity from the chord at that row's y (outer rows hold fewer cells).
        // POKE: GRID_CELL_PAD — px of air around a label when sizing row capacity.
        var cellPad = 14;
        // Size cells to the widest label in this book ("150" for Psalms), not "00".
        var minCellW = dc.getTextWidthInPixels(grid.itemCount >= 100 ? "000" : "00", Graphics.FONT_SMALL) + cellPad;
        _caps = [] as Lang.Array;
        _rowLeftA = [] as Lang.Array;
        _cellWA = [] as Lang.Array;
        _capTotal = 0;
        var r;
        for (r = 0; r < grid.visibleRows; r++) {
            var midY = top + r * cellH + cellH / 2;
            // Narrowest edge of the row so focus pills never clip on the circle.
            var edgeY = midY < h / 2 ? top + r * cellH : top + (r + 1) * cellH;
            var rowW = RoundLayout.chordWidth(edgeY, w, h);
            var cap = rowW / minCellW;
            if (cap > grid.columns) {
                cap = grid.columns;
            }
            if (cap < 1) {
                cap = 1;
            }
            _caps.add(cap);
            _rowLeftA.add(RoundLayout.chordLeft(edgeY, w, h));
            _cellWA.add(rowW / cap);
            _capTotal += cap;
        }
        if (_labels.size() != grid.itemCount) {
            _labels = [] as Lang.Array;
            var i;
            for (i = 1; i <= grid.itemCount; i++) {
                _labels.add(i.toString());
            }
        }
        _layTop = top;
        _layCount = grid.itemCount;
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
        if (displayRow >= _rowStart.size()) {
            return -1;
        }
        // Same cached rects the frame was drawn with (tap == what you see).
        var rowLeft = _rowLeftA[displayRow] as Lang.Number;
        var cap = _rowCap[displayRow] as Lang.Number;
        var cellW = _cellWA[displayRow] as Lang.Number;
        if (x < rowLeft || x >= rowLeft + cap * cellW) {
            return -1;
        }
        var col = ((x - rowLeft) / cellW).toNumber();
        if (col < 0 || col >= cap) {
            return -1;
        }
        var idx = (_rowStart[displayRow] as Lang.Number) + col;
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

    //! PERF: per-book heading index (one tiny resource per book), not a chapter JSON per focus move.
    function firstSectionTitle(book as Lang.Number, chapter as Lang.Number) as Lang.String or Null {
        if (_headsBook != book) {
            _headsBook = book;
            _heads = null;
            var rz = BsbIndex.heads(book);
            if (rz != null) {
                Perf.loads++;
                var hv = WatchUi.loadResource(rz as Lang.ResourceId);
                if (hv instanceof Lang.Array) {
                    _heads = hv as Lang.Array;
                }
            }
        }
        var hs = _heads;
        if (hs == null || chapter < 1 || chapter > hs.size()) {
            return null;
        }
        var t = hs[chapter - 1] as Lang.String;
        return t.length() > 0 ? t : null;
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
        var v = gridView();
        v.openChapterIndex(v.grid.focusIndex);
        return true;
    }

    function onHold(evt) as Lang.Boolean {
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
            v.openChapterIndex(idx);
        }
        return true;
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
