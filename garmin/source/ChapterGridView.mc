using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

//! Chapter grid, and (Dylan 2026-11-03) Go to's first step, the LETTER grid: same cells, look,
//! focus, snake navigation, tap flash and haptics. Mode LETTERS shows GoTo.letters() (the 17
//! letters that start a book, then "1–3") with the focused letter's books as the subtitle, and
//! START opens that letter (GoTo.openLetter).
const GRID_CHAPTERS = 0;
const GRID_LETTERS = 1;

class ChapterGridView extends WatchUi.View {
    var mode as Lang.Number = GRID_CHAPTERS;
    var pickOnly as Lang.Boolean = false; // Go to…: START on a chapter lists its headings (GoTo.mc)
    var toast as Lang.String or Null = null; // critique #5: chapter bookmark feedback
    var _toastTimer as Timer.Timer or Null = null;
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

    //! Turn this view into Go to's letter grid (call right after new).
    function setLetterMode() as Void {
        mode = GRID_LETTERS;
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
        var filter = mode == GRID_LETTERS;
        var n = filter ? GoTo.letters().size() : Books.chapterCount(AppState.selectedBook);
        grid = new SnakeGrid.Model(n, cols, rows);
        var focusIdx = filter ? GoTo.letterFocus : AppState.selectedChapter - 1;
        if (focusIdx < 0) {
            focusIdx = 0;
        }
        if (focusIdx >= n) {
            focusIdx = n > 0 ? n - 1 : 0;
        }
        grid.setFocusIndex(focusIdx);
        _gridBook = filter ? -1 : AppState.selectedBook;
        _firstIdx = 0;
        _top = -1;
        _bodyKey = -1;
        _hdrKey = -1;
        _subKey = -1;
    }

    function onShow() as Void {
        if (mode == GRID_LETTERS) {
            return;
        }
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
        Perf.navPaint("grid");
        if (toast != null) {
            RoundLayout.drawToastPill(dc, toast as Lang.String);
        }
        // v6: lay the focused chapter's reader out while focus rests here (instant open).
        if (flashIdx < 0 && _gridBook >= 0 && mode == GRID_CHAPTERS) {
            ReaderPrep.want(_gridBook, grid.focusedChapter());
        }
    }

    function onHide() as Void {
        ReaderPrep.pause();
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

    // DRAW-ONCE (v3): header (title + subtitle + rule) and body (every visible cell, unfocused)
    // each render once into a BufferedBitmap; a focus move re-renders only the subtitle
    // header and draws ONE cell (the focus pill). Keys include Palette.BG (theme).
    var _hdrRef = null;
    var _hdrKey as Lang.Number = -1;
    var _bodyRef = null;
    var _bodyKey as Lang.Number = -1;
    var _top as Lang.Number = -1;
    var _bottom as Lang.Number = 0;
    var _subY as Lang.Number = 0;
    var _subRows as Lang.Number = 2;
    var _theme as Lang.Number = -1;
    // Tap feedback: tapped cell flashes gold for FLASH_MS, then the chapter opens.
    var flashIdx as Lang.Number = -1;
    var _flashTimer = null;
    // POKE: TAP_FLASH_MS — gold flash before the reader opens (80-120 ms).
    const FLASH_MS = Feedback.FLASH_MS;

    function flashAndOpen(idx as Lang.Number) as Void {
        if (flashIdx >= 0) {
            return; // already opening
        }
        flashIdx = idx;
        grid.setFocusIndex(idx);
        Feedback.tick();
        WatchUi.requestUpdate(); // flash paints on the very next frame
        if (_flashTimer == null) {
            _flashTimer = new Timer.Timer();
        }
        (_flashTimer as Timer.Timer).start(method(:onFlashDone), FLASH_MS, false);
    }

    //! Whole-chapter bookmark on the focused cell, with the reader's toast (critique #5).
    function toggleChapterBookmark() as Void {
        if (mode == GRID_LETTERS) {
            return; // filters have nothing to bookmark
        }
        var book = _gridBook >= 0 ? _gridBook : AppState.selectedBook;
        var ch = grid.focusedChapter();
        var r = Bookmarks.toggle(book, ch, 0);
        // Same words as the reader's toast (a longer "Genesis 2 bookmarked" overflows the pill).
        showToast(r == :added ? "Bookmarked" : (r == :removed ? "Bookmark removed" : "Bookmarks full"));
        Feedback.tick();
    }

    function showToast(m as Lang.String) as Void {
        toast = m;
        if (_toastTimer == null) {
            _toastTimer = new Timer.Timer();
        }
        (_toastTimer as Timer.Timer).start(method(:onToastDone), RoundLayout.TOAST_MS, false);
        WatchUi.requestUpdate();
    }

    function onToastDone() as Void {
        toast = null;
        WatchUi.requestUpdate();
    }

    function onFlashDone() as Void {
        var idx = flashIdx;
        flashIdx = -1;
        openChapterIndex(idx);
    }

    function cellRect(idx as Lang.Number) as Lang.Array or Null {
        var rel = idx - _firstIdx;
        if (rel < 0) {
            return null;
        }
        var r;
        for (r = 0; r < grid.visibleRows; r++) {
            var cap = _caps[r] as Lang.Number;
            if (rel < cap) {
                var cw = _cellWA[r] as Lang.Number;
                return [(_rowLeftA[r] as Lang.Number) + rel * cw, _top + r * _cellH, cw];
            }
            rel -= cap;
        }
        return null;
    }

    function onUpdateImpl(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        _screenW = w;
        _screenH = h;
        if (_theme != Palette.BG) {
            _theme = Palette.BG;
            _hdrKey = -1;
            _bodyKey = -1;
        }
        var titleFont = Zoom.GRID_TITLE_FONT;
        var sf = Faces.light(Zoom.GRID_SUB_FONT); // secondary text: light face
        var sh = dc.getFontHeight(sf);
        var focusCh = grid.focusedChapter();
        var filter = mode == GRID_LETTERS;
        if (_top < 0 || (!filter && _gridBook != _headsBook)) {
            // Fixed grid top per book: always reserve the 2-row subtitle when the book has
            // headings, so a 1-row vs 2-row heading never shifts (and re-renders) the grid.
            if (!filter) {
                firstSectionTitle(_gridBook, 1);
            }
            layoutTitle(dc, w, h, titleFont);
            _subY = _titleY + dc.getFontHeight(titleFont) + 1;
            _subRows = filter ? 2 : subRowsFor(dc, w, h, sf, sh);
            // POKE: GRID_INSETS — the rule stays under the subtitle (top - 9); cells start 5px lower so the focus pill clears it, and
            // the bottom inset keeps the last row clear of the round edge.
            _top = _subY + ((filter || _heads != null) ? _subRows * (sh - 2) + 2 : 0) + 4 + 5;
            _bottom = h - RoundLayout.edgeMargin(w, h) - (h * 0.04).toNumber();
        }
        var top = _top;
        var titleY = _titleY;
        // POKE: GRID_MIN_CELL — a cell is never shorter than its label (Venu Sq 2's tall
        // font + 2-row subtitle overlapped rows): drop visible rows; the window scrolls.
        var minCell = (dc.getFontHeight(Zoom.GRID_CELL_FONT) * 4) / 5;
        while (grid.visibleRows > 1 && (_bottom - top) / grid.visibleRows < minCell) {
            grid.visibleRows -= 1;
        }
        var cellH = (_bottom - top) / grid.visibleRows;
        if (cellH < 18) {
            cellH = 18;
        }
        _gridTop = top;
        _cellH = cellH;
        if (_layTop != top || _layCount != grid.itemCount) {
            computeLayout(dc, top, cellH, w, h);
            _bodyKey = -1;
        }
        var subKey = filter ? 900000 + focusCh : AppState.selectedBook * 1000 + focusCh;
        if (_subKey != subKey) {
            _subKey = subKey;
            _subParts = null;
            var firstSec = filter ? GoTo.letterSummary(grid.focusIndex)
                : firstSectionTitle(AppState.selectedBook, focusCh);
            if (firstSec != null) {
                var st = firstSec as Lang.String;
                // POKE: GRID_SUBTITLE_WRAP — never clip: one line if it fits the chord, else pyramid two lines.
                var c1 = RoundLayout.chordWidth(_subY, w, h) - 6;
                if (dc.getTextWidthInPixels(st, sf) <= c1) {
                    _subParts = [st];
                } else {
                    var c2 = RoundLayout.chordWidth(_subY + sh - 2, w, h) - 6;
                    // POKE: GRID_SUBTITLE_WRAP — pyramid 2 lines; ellipsis only after line 2, at a word.
                    var two = RoundLayout.pyramidSplit(dc, st, sf, c1, c2);
                    if (two == null && _subRows == 3) {
                        var c3 = RoundLayout.chordWidth(_subY + 2 * (sh - 2), w, h) - 6;
                        two = RoundLayout.wrapThree(dc, st, sf, c1, c2, c3);
                    }
                    _subParts = two != null ? two : RoundLayout.pyramidSplitEllipsize(dc, st, sf, c1, c2);
                }
            }
        }
        // Window over the snake: keep focus visible.
        var total = _capTotal;
        var step = _caps[0] as Lang.Number;
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
        _rowCap = _caps;
        var idx0 = _firstIdx;
        var r;
        for (r = 0; r < grid.visibleRows; r++) {
            _rowStart.add(idx0);
            idx0 += _caps[r] as Lang.Number;
        }
        var bmps = Graphics has :createBufferedBitmap;
        // Header
        if (_hdrKey != subKey || _hdrRef == null || (_hdrRef as Graphics.BufferedBitmapReference).get() == null) {
            _hdrRef = null;
            if (bmps) {
                var hr = Graphics.createBufferedBitmap({:width => w, :height => top});
                var hb = (hr as Graphics.BufferedBitmapReference).get();
                if (hb != null) {
                    var hdc = (hb as Graphics.BufferedBitmap).getDc();
                    hdc.setColor(Palette.BG, Palette.BG);
                    hdc.clear();
                    drawHeader(hdc, w, h, titleY, titleFont, sf, sh, top);
                    _hdrRef = hr;
                    _hdrKey = subKey;
                }
            }
        }
        // Body
        var bodyKey = (filter ? 900000 : AppState.selectedBook * 1000) + _firstIdx;
        if (_bodyKey != bodyKey || _bodyRef == null || (_bodyRef as Graphics.BufferedBitmapReference).get() == null) {
            _bodyRef = null;
            if (bmps) {
                var br = Graphics.createBufferedBitmap({:width => w, :height => h - top});
                var bb = (br as Graphics.BufferedBitmapReference).get();
                if (bb != null) {
                    var bdc = (bb as Graphics.BufferedBitmap).getDc();
                    bdc.setColor(Palette.BG, Palette.BG);
                    bdc.clear();
                    drawCells(bdc, -top, -1);
                    _bodyRef = br;
                    _bodyKey = bodyKey;
                }
            }
        }
        Palette.applyBackground(dc);
        if (_hdrRef != null) {
            dc.drawBitmap(0, 0, _hdrRef as Graphics.BufferedBitmapReference);
        } else {
            drawHeader(dc, w, h, titleY, titleFont, sf, sh, top);
        }
        if (_bodyRef != null) {
            dc.drawBitmap(0, top, _bodyRef as Graphics.BufferedBitmapReference);
        } else {
            drawCells(dc, 0, grid.focusIndex);
        }
        // Focus pill (1 text) + tap flash.
        var smallH = dc.getFontHeight(Zoom.GRID_CELL_FONT);
        drawCell(dc, grid.focusIndex, smallH, 0, true);
        if (flashIdx >= 0) {
            var rc = cellRect(flashIdx);
            if (rc != null) {
                var x = rc[0] as Lang.Number;
                var y = rc[1] as Lang.Number;
                var cw = rc[2] as Lang.Number;
                dc.setColor(Palette.GOLD, Palette.GOLD);
                dc.fillRectangle(x - 1, y - 1, cw + 2, cellH + 2);
                dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawRectangle(x - 1, y - 1, cw + 2, cellH + 2);
                dc.setPenWidth(1);
                dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
                Perf.texts++;
                dc.drawText(x + cw / 2, y + cellH / 2 - smallH / 2, Zoom.GRID_CELL_FONT,
                            _labels[flashIdx] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    // Dylan 4:39 PM: the book name keeps the header font on every book (no step-down).
    // Too wide at the top of the dial -> the header moves down (<= 1 line) where the
    // circle is wider; only then the logged abbreviation. POKE: GRID_TITLE_SHIFT
    var _titleY as Lang.Number = 0;
    var _titleText as Lang.String = "";

    function layoutTitle(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, f as Graphics.FontDefinition) as Void {
        var name = mode == GRID_LETTERS ? GoTo.TITLE : Books.name(_gridBook);
        var y = RoundLayout.edgeMargin(w, h);
        var maxY = y + dc.getFontHeight(f);
        var tw = dc.getTextWidthInPixels(name, f);
        while (y < maxY && RoundLayout.chordWidth(y, w, h) - 8 < tw) {
            y += 2;
        }
        _titleY = y;
        _titleText = name;
        if (RoundLayout.chordWidth(y, w, h) - 8 < tw) {
            _titleText = Books.abbrevLabel(name);
            Perf.note("ABBR grid title '" + name + "' -> '" + _titleText + "'");
        }
    }

    function drawHeader(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, titleY as Lang.Number,
                        titleFont as Graphics.FontDefinition, sf as Graphics.FontType,
                        sh as Lang.Number, top as Lang.Number) as Void {
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        Perf.texts++;
        Faces.drawHead(dc, w / 2, titleY, titleFont, _titleText, Graphics.TEXT_JUSTIFY_CENTER);
        if (_subParts != null) {
            var sp = _subParts as Lang.Array;
            dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            // Rows centered in the reserved subtitle block (2 or 3 rows per book).
            var y = _subY + ((_subRows - sp.size()) * (sh - 2)) / 2;
            var k;
            for (k = 0; k < sp.size(); k++) {
                Perf.texts++;
                dc.drawText(w / 2, y + k * (sh - 2), sf, sp[k] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
        var ry = top - 9;
        var ruleLeft = RoundLayout.chordLeft(ry, w, h);
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ruleLeft, ry, ruleLeft + RoundLayout.chordWidth(ry, w, h), ry);
    }

    //! Every visible cell; dy shifts into bitmap space. focusIdx >= 0 draws that one as a pill.
    function drawCells(dc as Graphics.Dc, dy as Lang.Number, focusIdx as Lang.Number) as Void {
        var smallH = dc.getFontHeight(Zoom.GRID_CELL_FONT);
        var idx = _firstIdx;
        var r;
        for (r = 0; r < grid.visibleRows; r++) {
            var cap = _caps[r] as Lang.Number;
            var c;
            for (c = 0; c < cap; c++) {
                if (idx >= grid.itemCount) {
                    return;
                }
                if (idx != focusIdx) {
                    drawCell(dc, idx, smallH, dy, false);
                }
                idx++;
            }
        }
        if (focusIdx >= 0) {
            drawCell(dc, focusIdx, smallH, dy, true);
        }
    }

    function drawCell(dc as Graphics.Dc, idx as Lang.Number, smallH as Lang.Number, dy as Lang.Number,
                      focused as Lang.Boolean) as Void {
        var rc = cellRect(idx);
        if (rc == null) {
            return;
        }
        var x = rc[0] as Lang.Number;
        var y = (rc[1] as Lang.Number) + dy;
        var cellW = rc[2] as Lang.Number;
        if (focused) {
            dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_FG);
            dc.fillRectangle(x + 1, y + 1, cellW - 2, _cellH - 2);
            dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        }
        Perf.texts++;
        dc.drawText(x + cellW / 2, y + _cellH / 2 - smallH / 2, Zoom.GRID_CELL_FONT,
                    _labels[idx] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! PERF: per-row capacity / left / cell width for this grid top, computed once (not per frame).
    function computeLayout(dc as Graphics.Dc, top as Lang.Number, cellH as Lang.Number,
                           w as Lang.Number, h as Lang.Number) as Void {
        // Per-row capacity from the chord at that row's y (outer rows hold fewer cells).
        // POKE: GRID_CELL_PAD — px of air around a label when sizing row capacity.
        var cellPad = Zoom.GRID_CELL_PAD;
        // Size cells to the widest label in this book ("150" for Psalms), not "00"; the
        // letter grid to its widest label ("1–3").
        var widest = mode == GRID_LETTERS ? GoTo.DIGITS : (grid.itemCount >= 100 ? "000" : "00");
        var minCellW = dc.getTextWidthInPixels(widest, Zoom.GRID_CELL_FONT) + cellPad;
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
        if (mode == GRID_LETTERS) {
            _labels = GoTo.letters();
        } else if (_labels.size() != grid.itemCount) {
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
        if (mode == GRID_LETTERS) {
            GoTo.letterFocus = idx;
            GoTo.openLetter(_labels[idx] as Lang.String);
            return;
        }
        AppState.selectedBook = _gridBook >= 0 ? _gridBook : AppState.selectedBook;
        AppState.selectedChapter = grid.focusedChapter();
        if (pickOnly) {
            GoTo.openChapter(AppState.selectedBook, AppState.selectedChapter);
            return;
        }
        ReaderView.openFor(AppState.selectedBook, AppState.selectedChapter, Nav.IN);
    }

    //! PERF: per-book heading index (one tiny resource per book), not a chapter JSON per focus move.
    //! POKE: GRID_SUBTITLE_ROWS — reserve a 3rd subtitle row for this book only if some
    //! chapter heading cannot fit the 2-row pyramid (vivoactive5 Acts 13), so it wraps instead
    //! of ending in "…". Measured once per book; fixed per book so the grid never shifts.
    function subRowsFor(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number,
                        sf as Graphics.FontType, sh as Lang.Number) as Lang.Number {
        var hs = _heads;
        if (hs == null) {
            return 2;
        }
        var c1 = RoundLayout.chordWidth(_subY, w, h) - 6;
        var c2 = RoundLayout.chordWidth(_subY + sh - 2, w, h) - 6;
        var i;
        for (i = 0; i < hs.size(); i++) {
            var t = hs[i] as Lang.String;
            if (t.length() > 0 && dc.getTextWidthInPixels(t, sf) > c1
                && RoundLayout.pyramidSplit(dc, t, sf, c1, c2) == null) {
                return 3;
            }
        }
        return 2;
    }

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
    var _keys as KeyHold;
    var _drag as DragStep;

    function initialize() {
        BehaviorDelegate.initialize();
        // POKE: GRID_DRAG_PX — 0 = one step per swipe gesture; e.g. 30 = follow the finger.
        _drag = new DragStep(method(:dragStep), 0);
        // START: short = open, hold = chapter bookmark; hold DOWN repeats (critique #5, #1).
        _keys = new KeyHold(method(:activate), method(:holdStart), method(:repeatDown));
    }

    function onKeyPressed(evt as WatchUi.KeyEvent) as Lang.Boolean {
        _keys.pressed(evt.getKey());
        return false;
    }

    function onKeyReleased(evt as WatchUi.KeyEvent) as Lang.Boolean {
        _keys.released(evt.getKey());
        return false;
    }

    function holdStart() as Void {
        var v = gridView();
        if (v.flashIdx < 0) {
            v.toggleChapterBookmark();
        }
    }

    function repeatDown() as Void {
        onNextPage();
    }

    function gridView() as ChapterGridView {
        return WatchUi.getCurrentView()[0] as ChapterGridView;
    }

    function onNextPage() as Lang.Boolean {
        if (gridView().flashIdx >= 0) {
            return true; // input during the tap flash is ignored, not queued
        }
        if (_drag.swallow()) {
            return true; // the drag already stepped
        }
        if (TouchGuard.consumePage()) {
            return true;
        }
        gridView().grid.next();
        Feedback.step();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        if (gridView().flashIdx >= 0) {
            return true; // input during the tap flash is ignored, not queued
        }
        if (_drag.swallow()) {
            return true; // the drag already stepped
        }
        if (TouchGuard.consumePage()) {
            return true;
        }
        gridView().grid.prev();
        Feedback.step();
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
            return true; // acted on at release (KeyHold): short = open, hold = bookmark
        }
        return false;
    }

    function activate() as Lang.Boolean {
        var v = gridView();
        if (v.flashIdx >= 0) {
            return true; // a tap is already opening a chapter: never open twice
        }
        v.openChapterIndex(v.grid.focusIndex);
        return true;
    }

    function onHold(evt) as Lang.Boolean {
        var coords = evt.getCoordinates();
        var v = gridView();
        if (v.flashIdx >= 0 || v.mode == GRID_LETTERS) {
            return true; // filters have nothing to bookmark
        }
        var idx = v.chapterAt(coords[0], coords[1]);
        if (idx >= 0) {
            v.grid.setFocusIndex(idx);
        }
        v.toggleChapterBookmark();
        return true;
    }

    function onTap(evt) as Lang.Boolean {
        var coords = evt.getCoordinates();
        var v = gridView();
        var idx = v.chapterAt(coords[0], coords[1]);
        if (idx >= 0 && v.flashIdx < 0) {
            v.flashAndOpen(idx); // gold flash next frame + haptic, opens after FLASH_MS
        }
        return true;
    }

    function onDrag(evt as WatchUi.DragEvent) as Lang.Boolean {
        return _drag.onDrag(evt);
    }

    //! 0.9.7: a vertical drag steps as soon as the finger moves (was: on the swipe, at lift-off).
    function dragStep(d as Lang.Number) as Void {
        var v = gridView();
        if (v.flashIdx >= 0) {
            return;
        }
        if (d > 0) {
            v.grid.next();
        } else {
            v.grid.prev();
        }
        Feedback.step();
        WatchUi.requestUpdate();
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        if ((dir == WatchUi.SWIPE_UP || dir == WatchUi.SWIPE_DOWN) && _drag.swallow()) {
            return true; // the drag already stepped
        }
        // POKE: swipe moves one snake step; try whole-row (±columns) if it feels slow on Psalms.
        if (dir == WatchUi.SWIPE_UP) {
            TouchGuard.markPage();
            gridView().grid.next();
            Feedback.step();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            TouchGuard.markPage();
            gridView().grid.prev();
            Feedback.step();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            TouchGuard.markBack();
            leave();
            Nav.pop(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onBack() as Lang.Boolean {
        if (TouchGuard.consumeBack()) {
            return true;
        }
        leave();
        Nav.pop(WatchUi.SLIDE_RIGHT);
        return true;
    }

    //! Leaving the grid: remember where focus was (chapter, or the filter cell).
    function leave() as Void {
        var v = gridView();
        if (v.mode == GRID_LETTERS) {
            GoTo.letterFocus = v.grid.focusIndex;
        } else {
            AppState.selectedChapter = v.grid.focusedChapter();
        }
    }
}
