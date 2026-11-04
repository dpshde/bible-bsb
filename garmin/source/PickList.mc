using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

//! Round, scrolling pick list shared by every filter/browse level (Flipper parity).
//! Rows are sized to the circle chord at their y; the window scrolls to keep focus visible.
module PickList {
    //! Flipper BIBLE_FILTER_LABELS order (bible_books.c): All + 21 initials.
    const FILTER_LABELS = ["All", "A", "C", "D", "E", "G", "H", "I", "J", "K", "L",
        "M", "N", "O", "P", "R", "S", "T", "Z", "1", "2", "3"];

    //! Flipper get_filtered_books(): "All" = 66 books; letters = books whose name starts with it;
    //! "1", "2", "3" (Flipper parity) each match EVERY numbered book (first char 1-3).
    function booksForFilter(idx as Lang.Number) as Lang.Array {
        var out = [] as Lang.Array;
        var b;
        for (b = 0; b < Books.BOOK_COUNT; b++) {
            var c0 = Books.name(b).substring(0, 1);
            var numeric = idx >= 19; // "1", "2", "3"
            var isNum = c0.equals("1") || c0.equals("2") || c0.equals("3");
            if (idx == 0 || (numeric && isNum) || (!numeric && c0.equals(FILTER_LABELS[idx]))) {
                out.add(b);
            }
        }
        return out;
    }

    function bookLabels(books as Lang.Array) as Lang.Array {
        var out = [] as Lang.Array;
        var i;
        for (i = 0; i < books.size(); i++) {
            out.add(Books.name(books[i] as Lang.Number));
        }
        return out;
    }

    // Last drawn layout (touch hit-test): list top, row height, pixel scroll, visible rows.
    var lastTop as Lang.Number = 0;
    var lastRowH as Lang.Number = 0;
    var lastStart as Lang.Number = 0;
    var lastVis as Lang.Number = 0;
    var lastBottom as Lang.Number = 0;

    function indexAtY(y as Lang.Number, n as Lang.Number) as Lang.Number {
        if (lastRowH <= 0 || y < lastTop || y >= lastBottom) {
            return -1;
        }
        var i = (y - lastTop + _px.toNumber()) / lastRowH;
        return (i >= 0 && i < n) ? i : -1;
    }

    // POKE: PICKLIST_PAD — px kept clear on each side of a row inside its chord.
    const ROW_PAD = 10;

    //! Pyramid title (Dylan): one row if it fits the top chord, else two rows with
    //! row 1 <= row 2, each inside its own chord. Font steps down before ellipsizing.
    //! Returns the y just below the title block.
    function drawTitle(dc as Graphics.Dc, title as Lang.String, y as Lang.Number) as Lang.Number {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var fonts = Zoom.LIST_TITLE_FONTS;
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        var k;
        for (k = 0; k < fonts.size(); k++) {
            var f = fonts[k] as Graphics.FontDefinition;
            var fh = dc.getFontHeight(f);
            var y2 = y + fh - 3;
            var c1 = RoundLayout.chordWidth(y, w, h) - 2 * ROW_PAD;
            var c2 = RoundLayout.chordWidth(y2, w, h) - 2 * ROW_PAD;
            if (dc.getTextWidthInPixels(title, f) <= c1) {
                dc.drawText(w / 2, y, f, title, Graphics.TEXT_JUSTIFY_CENTER);
                return y + fh;
            }
            var rows = pyramid(dc, title, f, c1, c2);
            if (rows != null) {
                dc.drawText(w / 2, y, f, rows[0] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(w / 2, y2, f, rows[1] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
                return y2 + fh;
            }
        }
        var ff = Graphics.FONT_XTINY;
        var cw = RoundLayout.chordWidth(y, w, h) - 2 * ROW_PAD;
        dc.drawText(w / 2, y, ff, ellipsize(dc, title, ff, cw), Graphics.TEXT_JUSTIFY_CENTER);
        return y + dc.getFontHeight(ff);
    }

    function pyramid(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition,
                     w1 as Lang.Number, w2 as Lang.Number) as Lang.Array or Null {
        var words = ContentLoader.splitWords(text);
        var best = null;
        var bestW1 = -1;
        var k;
        for (k = 1; k < words.size(); k++) {
            var a = "";
            var b = "";
            var i;
            for (i = 0; i < words.size(); i++) {
                if (i < k) {
                    a = a.length() == 0 ? words[i] as Lang.String : a + " " + words[i];
                } else {
                    b = b.length() == 0 ? words[i] as Lang.String : b + " " + words[i];
                }
            }
            var wa = dc.getTextWidthInPixels(a, font);
            var wb = dc.getTextWidthInPixels(b, font);
            if (wa <= w1 && wb <= w2 && wa <= wb && wa > bestW1) {
                best = [a, b];
                bestW1 = wa;
            }
        }
        return best;
    }

    function ellipsize(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition,
                       maxW as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(text, font) <= maxW) {
            return text;
        }
        var t = text;
        while (t.length() > 1 && dc.getTextWidthInPixels(t + "...", font) > maxW) {
            t = t.substring(0, t.length() - 1);
        }
        return t + "...";
    }

    // ---------------------------------------------------------------------------------
    // DRAW-ONCE LIST (v3). Layout per (title, labels): title rendered once into a bitmap,
    // every row rendered once (normal + focused) into a row bitmap, rows blitted at a PIXEL
    // scroll offset so touch drag follows the finger. A frame = 1 title blit + ~vis row blits;
    // text is rasterized only for rows never seen before. Falls back to direct drawText
    // when BufferedBitmap is unavailable.
    // ---------------------------------------------------------------------------------
    var _cTitle as Lang.String or Null = null;
    var _cLabels as Lang.Array or Null = null;
    var _cTitleRows as Lang.Array = [] as Lang.Array; // [text, y, font]
    var _cTitleH as Lang.Number = 0;
    var _titleBmp = null;
    var _cTop as Lang.Number = 0;
    var _cBottom as Lang.Number = 0;
    var _cRowH as Lang.Number = 0;
    var _cVis as Lang.Number = 1;
    var _cRoom as Lang.Number = 0;   // text room = narrowest list chord - 2*ROW_PAD
    var _cPillW as Lang.Number = 0;
    var _cMaxW as Lang.Number = 0;    // widest row (window middle) - ROW_PAD: bitmap width
    var _rowBmp as Lang.Dictionary = {}; // idx*2 + focused -> BufferedBitmapReference
    var _fit as Lang.Dictionary = {};    // idx -> [font, text, fontH]
    // v6: room for the window + the rows one press up AND one press down will need.
    const ROW_CACHE_MAX = 24;
    var _sw as Lang.Number = 0;          // screen size, cached at layout (no per-row
    var _sh as Lang.Number = 0;          // System.getDeviceSettings() allocation)
    var _room as Lang.Dictionary = {};   // row top y -> text room (chord math once per y)

    // Scroll state (pixels). _px = top of the list window in content space.
    var _px as Lang.Float = 0.0;
    var _lastFocus as Lang.Number = -1;
    var _dragging as Lang.Boolean = false;
    var _dragY0 as Lang.Number = 0;
    var _dragPx0 as Lang.Float = 0.0;
    var _lastDragY as Lang.Number = 0;
    var _vel as Lang.Float = 0.0;       // px per momentum tick
    var _momTimer = null;
    var _focusOut as Lang.Number = -1;  // focus chosen by drag/momentum, taken by the view
    var _n as Lang.Number = 0;
    var _cBg as Lang.Number = -1;

    function layoutList(dc as Graphics.Dc, title as Lang.String, labels as Lang.Array) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        _sw = w;
        _sh = h;
        _room = {};
        _warmQ = [] as Lang.Array;
        _cTitleRows = [] as Lang.Array;
        var y = titleLayout(dc, title, RoundLayout.edgeMargin(w, h)) + 4;
        _cTitleH = y;
        var rowH = dc.getFontHeight(Zoom.LIST_FONT) + Zoom.LIST_ROW_PAD;
        // POKE: PICKLIST_BOTTOM — list window ends where the chord is >= 62% of the width.
        var bottom = h - RoundLayout.edgeMargin(w, h);
        while (bottom > y + rowH && RoundLayout.chordWidth(bottom, w, h) < (w * 0.62).toNumber()) {
            bottom -= 2;
        }
        var vis = (bottom - y) / rowH;
        if (vis < 1) {
            vis = 1;
        }
        bottom = y + vis * rowH;
        _cTop = y;
        _cBottom = bottom;
        _cRowH = rowH;
        _cVis = vis;
        // Rows slide through every y in the window: fit to the narrowest chord in it.
        var cTop = RoundLayout.chordWidth(y, w, h);
        var cBot = RoundLayout.chordWidth(bottom, w, h);
        var cMin = cTop < cBot ? cTop : cBot;
        _cRoom = cMin - 2 * ROW_PAD;
        _cPillW = cMin - ROW_PAD;
        var cMid = RoundLayout.chordWidth((y + bottom) / 2, w, h);
        _cMaxW = cMid - ROW_PAD;
        _fullW = {};
        _rowBmp = {};
        _fit = {};
        _titleBmp = null;
        _cTitle = title;
        _cLabels = labels;
        _n = labels.size();
    }

    function titleLayout(dc as Graphics.Dc, title as Lang.String, y as Lang.Number) as Lang.Number {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var fonts = Zoom.LIST_TITLE_FONTS;
        var k;
        for (k = 0; k < fonts.size(); k++) {
            var f = fonts[k] as Graphics.FontDefinition;
            var fh = dc.getFontHeight(f);
            var y2 = y + fh - 3;
            var c1 = RoundLayout.chordWidth(y, w, h) - 2 * ROW_PAD;
            var c2 = RoundLayout.chordWidth(y2, w, h) - 2 * ROW_PAD;
            if (dc.getTextWidthInPixels(title, f) <= c1) {
                _cTitleRows.add([title, y, f]);
                return y + fh;
            }
            var rows = pyramid(dc, title, f, c1, c2);
            if (rows != null) {
                _cTitleRows.add([rows[0], y, f]);
                _cTitleRows.add([rows[1], y2, f]);
                return y2 + fh;
            }
        }
        var ff = Graphics.FONT_XTINY;
        var cw = RoundLayout.chordWidth(y, w, h) - 2 * ROW_PAD;
        _cTitleRows.add([ellipsize(dc, title, ff, cw), y, ff]);
        return y + dc.getFontHeight(ff);
    }

    // Dylan 4:39 PM: every row uses ONE font (siblings match; no step-down for long names).
    // POKE: LIST_FONT
    const LIST_FONT = Zoom.LIST_FONT;
    var _fullW as Lang.Dictionary = {};

    function fullWidth(dc as Graphics.Dc, idx as Lang.Number, label as Lang.String) as Lang.Number {
        var v = _fullW[idx];
        if (v == null) {
            v = dc.getTextWidthInPixels(label, LIST_FONT);
            _fullW[idx] = v;
        }
        return v as Lang.Number;
    }

    //! Text room for a row whose top is at y: the narrower of its top/bottom chords.
    //! v6 PERF: was System.getDeviceSettings() + 2 chord sqrt per visible row per frame
    //! (the v4 book-list regression); now screen size is cached and each y computed once.
    function roomAt(y as Lang.Number) as Lang.Number {
        var v = _room[y];
        if (v != null) {
            return v as Lang.Number;
        }
        var a = RoundLayout.chordWidth(y, _sw, _sh);
        var b = RoundLayout.chordWidth(y + _cRowH, _sw, _sh);
        var r = (a < b ? a : b) - 2 * ROW_PAD;
        _room[y] = r;
        return r;
    }

    //! Home list's last row: opens the app menu (Bookmarks, Settings, About...).
    // POKE: MENU_ROW_LABEL — full label mid-list; "Menu" where the circle is narrow.
    const MENU_ROW_LABEL = "Menu & Settings";
    const MENU_ROW_SHORT = "Menu";

    //! short = this row sits where the circle is too narrow for the full name: use the
    //! book abbreviation (last resort, logged), never a smaller font.
    function fitFor(dc as Graphics.Dc, idx as Lang.Number, label as Lang.String, isShort as Lang.Boolean) as Lang.Array {
        var key = idx * 2 + (isShort ? 1 : 0);
        var f = _fit[key];
        if (f != null) {
            return f as Lang.Array;
        }
        var text = label;
        if (isShort && label.equals(MENU_ROW_LABEL)) {
            text = MENU_ROW_SHORT;
        } else if (isShort) {
            text = Books.abbrevLabel(label);
            if (!text.equals(label)) {
                Perf.note("ABBR row '" + label + "' -> '" + text + "'");
            }
        }
        var out = [LIST_FONT, ellipsize(dc, text, LIST_FONT, _cMaxW - ROW_PAD), dc.getFontHeight(LIST_FONT)];
        _fit[key] = out;
        return out;
    }

    //! Row content at (x0, y0) of dc: pill (if focused) + centered label.
    function drawRow(dc as Graphics.Dc, cx as Lang.Number, y0 as Lang.Number, fit as Lang.Array,
                     focused as Lang.Boolean, bg as Lang.Number) as Void {
        Perf.texts++;
        if (focused) {
            dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_BG);
            var pw = dc.getTextWidthInPixels(fit[1] as Lang.String, fit[0] as Graphics.FontDefinition) + 2 * ROW_PAD;
            if (pw < _cPillW) {
                pw = _cPillW;
            }
            if (pw > _cMaxW) {
                pw = _cMaxW;
            }
            dc.fillRectangle(cx - pw / 2, y0, pw, _cRowH - 2);
            dc.setColor(Palette.FOCUS_FG, Palette.FOCUS_BG);
        } else {
            dc.setColor(Palette.TEXT, bg);
        }
        dc.drawText(cx, y0 + (_cRowH - 2 - (fit[2] as Lang.Number)) / 2, fit[0] as Graphics.FontDefinition,
                    fit[1] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function rowBitmap(dc as Graphics.Dc, idx as Lang.Number, label as Lang.String, focused as Lang.Boolean,
                       isShort as Lang.Boolean) {
        var key = idx * 4 + (isShort ? 2 : 0) + (focused ? 1 : 0);
        var ref = _rowBmp[key];
        if (ref != null) {
            var got = (ref as Graphics.BufferedBitmapReference).get();
            if (got != null) {
                return ref;
            }
        }
        if (_rowBmp.size() >= ROW_CACHE_MAX) {
            evictRows();
        }
        var bw = _cMaxW + 2;
        ref = Graphics.createBufferedBitmap({:width => bw, :height => _cRowH});
        var bmp = (ref as Graphics.BufferedBitmapReference).get();
        if (bmp == null) {
            return null;
        }
        var bdc = (bmp as Graphics.BufferedBitmap).getDc();
        bdc.setColor(Palette.BG, Palette.BG);
        bdc.clear();
        drawRow(bdc, bw / 2, 0, fitFor(bdc, idx, label, isShort), focused, Palette.BG);
        _rowBmp[key] = ref;
        return ref;
    }

    function evictRows() as Void {
        var first = (_px / (_cRowH > 0 ? _cRowH : 1)).toNumber();
        var keys = _rowBmp.keys();
        var i;
        for (i = 0; i < keys.size(); i++) {
            var ri = (keys[i] as Lang.Number) / 4;
            if (ri < first - 2 || ri > first + _cVis + 2) {
                _rowBmp.remove(keys[i]);
            }
        }
        if (_rowBmp.size() >= ROW_CACHE_MAX) {
            _rowBmp = {};
        }
    }

    function maxPx() as Lang.Float {
        // Focus may ride the middle row down to the last item (blank rows below it).
        var m = (_n - 1 - (_cVis - 1) / 2) * _cRowH;
        return (m > 0 ? m : 0).toFloat();
    }

    function clampPx() as Void {
        if (_px < 0) {
            _px = 0.0;
        }
        var m = maxPx();
        if (_px > m) {
            _px = m;
        }
    }

    function centerIndex() as Lang.Number {
        var i = ((_px + (_cVis * _cRowH) / 2) / _cRowH).toNumber();
        if (i < 0) {
            i = 0;
        }
        if (i >= _n) {
            i = _n - 1;
        }
        return i;
    }

    //! Views call this first in onUpdate: focus chosen by a drag / momentum wins.
    //! A drag/momentum focus belongs to the list it was made on (module state is shared):
    //! a different list (edge pass D12: stale home-list focus hid the filtered list's
    //! highlight) drops it, and focus is always clamped into range.
    function takeFocus(focus as Lang.Number, labels as Lang.Array) as Lang.Number {
        if (_cLabels == null || _cLabels != labels) {
            _focusOut = -1;
            stopMomentum();
        }
        var n = labels.size();
        if (n > 0 && focus >= n) {
            focus = n - 1;
        }
        if (_focusOut >= n) {
            _focusOut = -1;
        }
        if (_focusOut >= 0) {
            var f = _focusOut;
            _focusOut = -1;
            _lastFocus = f;
            return f;
        }
        return focus;
    }

    // POKE: PICKLIST_DRAG — list follows the finger 1:1; release keeps velocity, decays
    // by MOMENTUM_DECAY per 50 ms tick, then focus = row under the middle.
    const MOMENTUM_DECAY = 0.80;
    const MOMENTUM_TICK_MS = 50;

    function onDrag(evt as WatchUi.DragEvent) as Lang.Boolean {
        var y = evt.getCoordinates()[1];
        var t = evt.getType();
        if (t == WatchUi.DRAG_TYPE_START) {
            stopMomentum();
            _dragging = true;
            _dragY0 = y;
            _lastDragY = y;
            _dragPx0 = _px;
            _vel = 0.0;
            _dragFocus = centerIndex();
            return true;
        }
        if (!_dragging) {
            return false;
        }
        if (y - _dragY0 > 6 || _dragY0 - y > 6) {
            _movedAt = System.getTimer();
        }
        _vel = (_lastDragY - y).toFloat();
        _lastDragY = y;
        _px = _dragPx0 + (_dragY0 - y);
        clampPx();
        setDragFocus(centerIndex());
        if (t == WatchUi.DRAG_TYPE_STOP) {
            _dragging = false;
            if (_vel > 2 || _vel < -2) {
                startMomentum();
            } else {
                snapPx();
            }
        }
        WatchUi.requestUpdate();
        return true;
    }

    var _movedAt as Lang.Number = -100000;
    var _dragFocus as Lang.Number = -1;

    //! Drag / momentum moved the middle row: hand it to the view, with a detent tick (v7)
    //! each time a new row reaches the middle (Feedback rate-limits fast flings).
    function setDragFocus(i as Lang.Number) as Void {
        if (i != _dragFocus) {
            if (_dragFocus >= 0) {
                Feedback.step();
            }
            _dragFocus = i;
        }
        _focusOut = i;
    }

    //! A real drag just happened: the swipe/page behavior the OS derives from the same
    //! gesture must not move focus a second time.
    function swallowSwipe() as Lang.Boolean {
        return _dragging || System.getTimer() - _movedAt < 350;
    }

    function dragActive() as Lang.Boolean {
        return _dragging || _momTimer != null;
    }

    function startMomentum() as Void {
        if (_momTimer == null) {
            _momTimer = new Timer.Timer();
        }
        (_momTimer as Timer.Timer).start(new Lang.Method(PickList, :onMomentum), MOMENTUM_TICK_MS, true);
    }

    function stopMomentum() as Void {
        if (_momTimer != null) {
            (_momTimer as Timer.Timer).stop();
            _momTimer = null;
        }
    }

    //! Settle on a row boundary (crisp final frame, no sliced rows).
    function snapPx() as Void {
        _px = ((_px / _cRowH + 0.5).toNumber() * _cRowH).toFloat();
        clampPx();
        _focusOut = centerIndex();
    }

    function onMomentum() as Void {
        _vel = _vel * MOMENTUM_DECAY;
        _px = _px + _vel;
        var before = _px;
        clampPx();
        setDragFocus(centerIndex());
        if ((_vel < 0.6 && _vel > -0.6) || before != _px) {
            stopMomentum();
            snapPx();
        }
        WatchUi.requestUpdate();
    }

    function draw(dc as Graphics.Dc, title as Lang.String, labels as Lang.Array, focus as Lang.Number) as Void {
        Palette.applyBackground(dc);
        var w = dc.getWidth();
        if (_cBg != Palette.BG) {
            _cBg = Palette.BG; // theme toggled: every cached row/title bitmap is stale
            invalidate();
        }
        if (_cLabels == null || _cLabels != labels || _cTitle == null || !(_cTitle as Lang.String).equals(title)) {
            layoutList(dc, title, labels);
            _lastFocus = -1;
            stopMomentum();
            _dragging = false;
        }
        var bmps = Graphics has :createBufferedBitmap;
        // Title: one blit (rendered once per layout).
        if (bmps && _titleBmp == null) {
            var tr0 = Graphics.createBufferedBitmap({:width => w, :height => _cTitleH});
            var tb = (tr0 as Graphics.BufferedBitmapReference).get();
            if (tb != null) {
                var tdc = (tb as Graphics.BufferedBitmap).getDc();
                tdc.setColor(Palette.BG, Palette.BG);
                tdc.clear();
                drawTitleRows(tdc, w);
                _titleBmp = tr0;
            }
        }
        if (_titleBmp != null && (_titleBmp as Graphics.BufferedBitmapReference).get() != null) {
            dc.drawBitmap(0, 0, _titleBmp as Graphics.BufferedBitmapReference);
        } else {
            drawTitleRows(dc, w);
        }
        // Buttons moved focus -> re-center the window on it (instant, no animation).
        if (!dragActive() && focus != _lastFocus) {
            _px = ((focus - (_cVis - 1) / 2) * _cRowH).toFloat();
            clampPx();
            _lastFocus = focus;
        }
        var n = labels.size();
        if (n == 0) {
            // Filter with no books (Flipper's "K": every Kings book is numbered).
            dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            Perf.texts++;
            dc.drawText(w / 2, (_cTop + _cBottom) / 2 - dc.getFontHeight(Graphics.FONT_TINY) / 2,
                        Graphics.FONT_TINY, "No books", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        _warmQ = [] as Lang.Array; // last frame's predictions are stale now
        var rowH = _cRowH;
        var pxi = _px.toNumber();
        var first = pxi / rowH;
        var off = pxi - first * rowH;
        lastTop = _cTop;
        lastBottom = _cBottom;
        lastRowH = rowH;
        lastStart = first;
        lastVis = _cVis;
        dc.setClip(0, _cTop, w, _cBottom - _cTop);
        var r;
        for (r = 0; r <= _cVis; r++) {
            var i = first + r;
            if (i >= n) {
                break;
            }
            var y = _cTop + r * rowH - off;
            if (y >= _cBottom) {
                break; // fully below the clip: drawing (or caching) it is wasted work
            }
            var label = labels[i] as Lang.String;
            var isShort = fullWidth(dc, i, label) > roomAt(y);
            // v6: a frame only blits cached rows; a miss is drawn directly (cheaper than
            // allocating a bitmap mid-scroll) and its bitmap is built on an idle slice.
            var ref = bmps ? cachedRow(i, i == focus, isShort) : null;
            if (ref != null) {
                dc.drawBitmap(w / 2 - (_cMaxW + 2) / 2, y, ref);
            } else {
                drawRow(dc, w / 2, y, fitFor(dc, i, label, isShort), i == focus, Graphics.COLOR_TRANSPARENT);
                if (bmps) {
                    _warmQ.add([i, i == focus, isShort]);
                }
            }
        }
        dc.clearClip();
        if (bmps && !dragActive()) {
            // Predict the next press either way (button, or a swipe step) so it is all blits.
            queueFrame(n, focus + 1 < n ? focus + 1 : 0);
            queueFrame(n, focus > 0 ? focus - 1 : n - 1);
        }
        if (bmps && _warmQ.size() > 0) {
            scheduleWarm();
        }
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        if (off != 0) {
            return;
        }
        if (pxi > 0) {
            dc.fillPolygon([[w / 2 - 5, _cTop - 1], [w / 2 + 5, _cTop - 1], [w / 2, _cTop - 5]]);
        }
        if (first + _cVis < n) {
            dc.fillPolygon([[w / 2 - 5, _cBottom], [w / 2 + 5, _cBottom], [w / 2, _cBottom + 4]]);
        }
    }

    function drawTitleRows(dc as Graphics.Dc, w as Lang.Number) as Void {
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        var t;
        for (t = 0; t < _cTitleRows.size(); t++) {
            var tr = _cTitleRows[t] as Lang.Array;
            Perf.texts++;
            Faces.drawHead(dc, w / 2, tr[1] as Lang.Number, tr[2] as Graphics.FontDefinition, tr[0] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function cachedRow(idx as Lang.Number, focused as Lang.Boolean, isShort as Lang.Boolean) {
        var ref = _rowBmp[idx * 4 + (isShort ? 2 : 0) + (focused ? 1 : 0)];
        if (ref != null && (ref as Graphics.BufferedBitmapReference).get() != null) {
            return ref;
        }
        return null;
    }

    // ---- Idle warm-up (v6) -------------------------------------------------------------
    // POKE: WARM_TICK_MS / WARM_BUDGET_MS — row bitmaps are built on one Timer in slices of
    // at most WARM_BUDGET_MS, never inside a frame, and never trigger a repaint.
    const WARM_TICK_MS = 50; // CIQ minimum timer period
    const WARM_BUDGET_MS = 10;
    var _warmQ as Lang.Array = [] as Lang.Array; // [idx, focused, isShort]
    var _warmTimer = null;

    //! Queue the uncached rows a button press that lands on focus f would draw.
    function queueFrame(n as Lang.Number, f as Lang.Number) as Void {
        var labels = _cLabels;
        if (labels == null || _cRowH <= 0) {
            return;
        }
        var px = (f - (_cVis - 1) / 2) * _cRowH;
        var m = maxPx().toNumber();
        if (px > m) {
            px = m;
        }
        if (px < 0) {
            px = 0;
        }
        var first = px / _cRowH;
        var mdc = null;
        var r;
        for (r = 0; r < _cVis; r++) {
            var i = first + r;
            if (i >= n) {
                break;
            }
            var y = _cTop + r * _cRowH;
            var fw = _fullW[i];
            if (fw == null) {
                if (mdc == null) {
                    mdc = MeasureDc.get();
                    if (mdc == null) {
                        return;
                    }
                }
                fw = fullWidth(mdc as Graphics.Dc, i, (labels as Lang.Array)[i] as Lang.String);
            }
            var isShort = (fw as Lang.Number) > roomAt(y);
            if (cachedRow(i, i == f, isShort) == null) {
                _warmQ.add([i, i == f, isShort]);
            }
        }
    }

    function scheduleWarm() as Void {
        if (_warmTimer == null) {
            _warmTimer = new Timer.Timer();
        } else {
            (_warmTimer as Timer.Timer).stop();
        }
        (_warmTimer as Timer.Timer).start(new Lang.Method(PickList, :onWarm), WARM_TICK_MS, false);
    }

    function stopWarm() as Void {
        if (_warmTimer != null) {
            (_warmTimer as Timer.Timer).stop();
        }
        _warmQ = [] as Lang.Array;
    }

    function onWarm() as Void {
        var t0 = System.getTimer();
        var pt0 = Perf.start();
        var labels = _cLabels;
        var mdc = MeasureDc.get();
        if (labels == null || mdc == null) {
            _warmQ = [] as Lang.Array;
            return;
        }
        var n = 0;
        while (_warmQ.size() > 0 && System.getTimer() - t0 < WARM_BUDGET_MS) {
            var q = _warmQ[0] as Lang.Array;
            _warmQ = _warmQ.slice(1, null);
            var i = q[0] as Lang.Number;
            if (i < (labels as Lang.Array).size() && cachedRow(i, q[1] as Lang.Boolean, q[2] as Lang.Boolean) == null) {
                rowBitmap(mdc as Graphics.Dc, i, (labels as Lang.Array)[i] as Lang.String,
                          q[1] as Lang.Boolean, q[2] as Lang.Boolean);
                n++;
            }
        }
        if (n > 0) {
            Perf.idle("rows", pt0);
        }
        if (_warmQ.size() > 0) {
            scheduleWarm();
        }
    }

    //! Theme toggled: drop every cached bitmap so rows redraw in the new palette.
    function invalidate() as Void {
        stopWarm();
        _cLabels = null;
        _rowBmp = {};
        _titleBmp = null;
    }

    //! A view above the list was shown: drop the cached row/title bitmaps (keep the layout).
    //! On fr265 the views above (reader, grid, P1 menus) push these out of the graphics pool,
    //! and a purged BufferedBitmapReference can come back non-null but blank: Home after
    //! BACK from a chapter grid drew only its scroll arrows. Re-rendering costs one frame of
    //! direct draws; the idle warm-up rebuilds the cache.
    function dropBitmaps() as Void {
        stopWarm();
        _rowBmp = {};
        _titleBmp = null;
    }

    //! Open a book like Flipper: single-chapter books skip the 1-cell chapter grid.
    function openBook(bi as Lang.Number) as Void {
        AppState.selectedBook = bi;
        AppState.selectedChapter = LastReadApp.chapterFor(bi); // last-read chapter, else 1
        if (Books.chapterCount(bi) == 1) {
            ReaderView.openFor(bi, 1, Nav.IN);
            return;
        }
        Nav.push(new ChapterGridView(), new ChapterGridDelegate(), WatchUi.SLIDE_LEFT);
    }
}

class PickListView extends WatchUi.View {
    var title as Lang.String;
    var labels as Lang.Array;
    var focus as Lang.Number = 0;

    function initialize(title as Lang.String, labels as Lang.Array) {
        View.initialize();
        me.title = title;
        me.labels = labels;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        focus = PickList.takeFocus(focus, labels);
        PickList.draw(dc, title, labels, focus);
    }

    function onShow() as Void {
        PickList.dropBitmaps();
    }

    function onHide() as Void {
        PickList.stopWarm();
    }
}

//! kind: 0 = book list (books[] -> openBook), 1 = A–Z filter (-> filtered book list)
class PickListDelegate extends WatchUi.BehaviorDelegate {
    var _view as PickListView;
    var _kind as Lang.Number;
    var _books as Lang.Array;

    function initialize(view as PickListView, kind as Lang.Number, books as Lang.Array) {
        BehaviorDelegate.initialize();
        _view = view;
        _kind = kind;
        _books = books;
    }

    function onNextPage() as Lang.Boolean {
        if (PickList.swallowSwipe()) {
            return true;
        }
        var n = _view.labels.size();
        if (n > 0) {
            _view.focus = (_view.focus + 1) % n;
            Feedback.step();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        if (PickList.swallowSwipe()) {
            return true;
        }
        var n = _view.labels.size();
        if (n > 0) {
            _view.focus = (_view.focus + n - 1) % n;
            Feedback.step();
        }
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
        if (_view.labels.size() == 0) {
            return true;
        }
        if (_kind == 1) {
            var books = PickList.booksForFilter(_view.focus);
            var title = _view.focus == 0 ? "All books" : "Books: " + PickList.FILTER_LABELS[_view.focus];
            var v = new PickListView(title, PickList.bookLabels(books));
            Nav.push(v, new PickListDelegate(v, 0, books), WatchUi.SLIDE_LEFT);
            return true;
        }
        PickList.openBook(_books[_view.focus] as Lang.Number);
        return true;
    }

    function onDrag(evt as WatchUi.DragEvent) as Lang.Boolean {
        return PickList.onDrag(evt);
    }

    //! Tap: hit-test the rows PickList.draw just laid out; open the TAPPED row.
    function onTap(evt as WatchUi.ClickEvent) as Lang.Boolean {
        var idx = PickList.indexAtY(evt.getCoordinates()[1], _view.labels.size());
        if (idx >= 0) {
            _view.focus = idx;
            activate();
        }
        return true;
    }

    function onBack() as Lang.Boolean {
        Nav.pop(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            return onNextPage();
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            return onPreviousPage();
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            return onBack();
        }
        return false;
    }
}

//! Home (book list) app menu — Flipper home: Left = Collection(Bookmarks), Right = Testament,
//! Right again = Filter; plus Continue, Settings and About (v6). Opened by MENU (hold UP /
//! hold the lower button), the list's last row "Menu & Settings", or a tap on the title.
class HomeMenu2Delegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    //! [book, chapter, verse] to continue at, or null (nothing read yet).
    static function resumeTarget() as Lang.Array or Null {
        var p = LastReadApp.pending;
        if (p == null) {
            p = LastReadApp.stored();
        }
        return p;
    }

    static function items() as Lang.Array {
        var out = [] as Lang.Array; // [label, sublabel or null, id]
        var r = resumeTarget();
        if (r != null) {
            out.add(["Continue", Books.refLabel(r[0] as Lang.Number, r[1] as Lang.Number, r[2] as Lang.Number), :resume]);
        }
        // Critique #1: jump anywhere by letter > book > chapter > section (GoTo.mc). It also
        // replaces "Filter books" (critique #9: the letter list is the filter).
        out.add(["Go to…", "Book, chapter, verse", :goto]);
        // Critique #11: sync state on the watch where people look, e.g. "2 · synced 4m ago".
        out.add(["Bookmarks", HwSync.bookmarksLine(Bookmarks.load().size()), :bookmarks]);
        out.add(["By Testament", "Old, New", :testament]);
        out.add(["Settings", "Scroll, theme, buzz", :settings]);
        out.add(["About", AppInfo.name(), :about]);
        return out;
    }

    static function open() as Void {
        var menu = UiMenu.create("Menu");
        var list = items();
        var i;
        for (i = 0; i < list.size(); i++) {
            var it = list[i] as Lang.Array;
            menu.addItem(UiMenu.item(it[0] as Lang.String, it[1] as Lang.String or Null, it[2] as Lang.Symbol));
        }
        NativeLists.homeMenu = menu; // sync-finished updates its Bookmarks sublabel
        Nav.push(menu, new HomeMenu2Delegate(), WatchUi.SLIDE_LEFT);
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Perf.nav("sel");
        var id = item.getId();
        if (id == :settings) {
            // Settings opens on top of the menu: Back returns here, like Garmin's own menus.
            NativeLists.openSettings();
            return;
        }
        if (id == :about) {
            Nav.push(new AboutView(), new AboutDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        // Critique #10: lists opened from this menu sit on top of it, so BACK returns here.
        // A jump to a reference resets the stack to Home > Grid > Reader (Nav.openRef).
        if (id == :bookmarks) {
            NativeLists.openBookmarks();
        } else if (id == :testament) {
            NativeLists.openBrowse();
        } else if (id == :goto) {
            GoTo.open();
        } else if (id == :resume) {
            var r = resumeTarget();
            if (r != null) {
                Nav.openRef(r[0] as Lang.Number, r[1] as Lang.Number, r[2] as Lang.Number, true);
            }
        }
    }

    function onBack() as Void {
        NativeLists.homeMenu = null;
        Nav.pop(WatchUi.SLIDE_RIGHT);
    }
}

//! About: what this is, and that it is all on the watch.
class AboutView extends WatchUi.View {
    // POKE: ABOUT_VERSION
    const VERSION = "0.9.7"; // About screen (was "v7" through store 0.9.4)

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Palette.applyBackground(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        var tf = Graphics.FONT_SMALL;
        var bf = Graphics.FONT_XTINY;
        var th = dc.getFontHeight(tf);
        var bh = dc.getFontHeight(bf);
        var rows = ["Berean Standard Bible", "Whole Bible on the watch", "Works offline", VERSION];
        var total = th + 6 + rows.size() * bh;
        var y = (h - total) / 2;
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        Faces.drawHead(dc, w / 2, y, tf, AppInfo.name(), Graphics.TEXT_JUSTIFY_CENTER);
        y += th + 6;
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        var i;
        for (i = 0; i < rows.size(); i++) {
            dc.drawText(w / 2, y + i * bh, bf, rows[i] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class AboutDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Lang.Boolean {
        Nav.pop(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSelect() as Lang.Boolean {
        Nav.pop(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSwipe(evt) as Lang.Boolean {
        if (evt.getDirection() == WatchUi.SWIPE_RIGHT) {
            Nav.pop(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }
}
