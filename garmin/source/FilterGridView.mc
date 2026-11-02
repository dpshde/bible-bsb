using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Timer;
using Toybox.WatchUi;

//! Flipper "< Select Filter >" (bible_view_book_filter.c, 5-col grid) on a round screen:
//! ALL 22 options (All, A..Z initials, 1, 2, 3) visible at once, rows reflowed to the circle
//! chord so nothing clips or hides off-screen. Reading order = Flipper order.
//! Drawn once into a bitmap; a focus move draws one cell.
class FilterGridView extends WatchUi.View {
    var focus as Lang.Number = 0;
    var flashIdx as Lang.Number = -1;
    var _flashTimer = null;
    var _rects as Lang.Array = [] as Lang.Array; // [x, y, w, h] per label
    var _bodyRef = null;
    var _theme as Lang.Number = -1;
    var _font as Graphics.FontDefinition = Graphics.FONT_SMALL;
    var _fontH as Lang.Number = 0;
    var _layoutW as Lang.Number = -1;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var t0 = Perf.start();
        onUpdateImpl(dc);
        Perf.end("filter", t0);
    }

    //! "All" alone on the top row (Flipper's first cell, widest label), then the 21 letter /
    //! number cells spread over the rows below in proportion to each row's chord capacity
    //! (largest remainder), so the grid follows the circle. Steps the font down until all
    //! 22 fit. POKE: FILTER_GRID_PAD (cell air).
    function layout(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var n = PickList.FILTER_LABELS.size() - 1; // letters + numbers
        var titleY = RoundLayout.edgeMargin(w, h);
        var top = titleY + dc.getFontHeight(Graphics.FONT_TINY) + 4;
        var bottom = h - RoundLayout.edgeMargin(w, h) + 2;
        var fonts = [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
        var k;
        for (k = 0; k < fonts.size(); k++) {
            var f = fonts[k] as Graphics.FontDefinition;
            var fh = dc.getFontHeight(f);
            var cw = dc.getTextWidthInPixels("M", f) + 16;
            var allW = dc.getTextWidthInPixels("All", f) + 20;
            var rows;
            for (rows = 4; rows <= 7; rows++) {
                var rh = (bottom - top) / rows;
                if (rh < fh) {
                    break;
                }
                var caps = [] as Lang.Array;
                var sum = 0;
                var r;
                for (r = 1; r < rows; r++) {
                    var y0 = top + r * rh;
                    var edge = (y0 + rh / 2) < h / 2 ? y0 : y0 + rh;
                    var cap = (RoundLayout.chordWidth(edge, w, h) - 10) / cw;
                    caps.add(cap > 0 ? cap : 0);
                    sum += cap > 0 ? cap : 0;
                }
                if (sum < n) {
                    continue;
                }
                var counts = [] as Lang.Array;
                var bumped = [] as Lang.Array;
                var got = 0;
                for (r = 0; r < caps.size(); r++) {
                    var q = ((caps[r] as Lang.Number) * n) / sum;
                    counts.add(q);
                    bumped.add(false);
                    got += q;
                }
                while (got < n) {
                    var best = -1;
                    var bestRem = -1;
                    for (r = 0; r < caps.size(); r++) {
                        var rem = ((caps[r] as Lang.Number) * n) % sum;
                        if (!(bumped[r] as Lang.Boolean) && (counts[r] as Lang.Number) < (caps[r] as Lang.Number)
                            && rem > bestRem) {
                            best = r;
                            bestRem = rem;
                        }
                    }
                    if (best < 0) {
                        break;
                    }
                    counts[best] = (counts[best] as Lang.Number) + 1;
                    bumped[best] = true;
                    got++;
                }
                if (got < n) {
                    continue;
                }
                _rects = [] as Lang.Array;
                _rects.add([(w - allW) / 2, top, allW, rh]);
                var y = top + rh;
                for (r = 0; r < counts.size(); r++) {
                    var c = counts[r] as Lang.Number;
                    if (c == 0) {
                        continue;
                    }
                    var edge2 = (y + rh / 2) < h / 2 ? y : y + rh;
                    var chord = RoundLayout.chordWidth(edge2, w, h) - 10;
                    var cellW = chord / c;
                    var maxW = cw + cw / 2;
                    if (cellW > maxW) {
                        cellW = maxW;
                    }
                    var left = (w - cellW * c) / 2;
                    var j;
                    for (j = 0; j < c; j++) {
                        _rects.add([left + j * cellW, y, cellW, rh]);
                    }
                    y += rh;
                }
                _font = f;
                _fontH = fh;
                _layoutW = w;
                return;
            }
        }
    }

    function onUpdateImpl(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        if (_layoutW != w) {
            layout(dc);
            _bodyRef = null;
        }
        if (_theme != Palette.BG) {
            _theme = Palette.BG;
            _bodyRef = null;
        }
        if (_bodyRef == null || (_bodyRef as Graphics.BufferedBitmapReference).get() == null) {
            _bodyRef = null;
            if (Graphics has :createBufferedBitmap) {
                var br = Graphics.createBufferedBitmap({:width => w, :height => dc.getHeight()});
                var bb = (br as Graphics.BufferedBitmapReference).get();
                if (bb != null) {
                    var bdc = (bb as Graphics.BufferedBitmap).getDc();
                    drawAll(bdc);
                    _bodyRef = br;
                }
            }
        }
        if (_bodyRef != null) {
            dc.drawBitmap(0, 0, _bodyRef as Graphics.BufferedBitmapReference);
        } else {
            drawAll(dc);
        }
        drawCell(dc, focus, true, false);
        if (flashIdx >= 0) {
            drawCell(dc, flashIdx, true, true);
        }
    }

    function drawAll(dc as Graphics.Dc) as Void {
        Palette.applyBackground(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        Perf.texts++;
        RoundLayout.drawCenteredInChord(dc, RoundLayout.edgeMargin(w, h), "Filter books", Graphics.FONT_TINY);
        var i;
        for (i = 0; i < _rects.size(); i++) {
            drawCell(dc, i, false, false);
        }
    }

    function drawCell(dc as Graphics.Dc, i as Lang.Number, focused as Lang.Boolean, flash as Lang.Boolean) as Void {
        if (i < 0 || i >= _rects.size()) {
            return;
        }
        var rc = _rects[i] as Lang.Array;
        var x = rc[0] as Lang.Number;
        var y = rc[1] as Lang.Number;
        var cw = rc[2] as Lang.Number;
        var ch = rc[3] as Lang.Number;
        if (focused) {
            dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_BG);
            dc.fillRectangle(x + 1, y + 1, cw - 2, ch - 2);
            if (flash) {
                dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawRectangle(x, y, cw, ch);
                dc.setPenWidth(1);
            }
            dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        }
        Perf.texts++;
        dc.drawText(x + cw / 2, y + (ch - _fontH) / 2, _font, PickList.FILTER_LABELS[i] as Lang.String,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    function indexAt(x as Lang.Number, y as Lang.Number) as Lang.Number {
        var i;
        for (i = 0; i < _rects.size(); i++) {
            var rc = _rects[i] as Lang.Array;
            if (x >= (rc[0] as Lang.Number) && x < (rc[0] as Lang.Number) + (rc[2] as Lang.Number)
                && y >= (rc[1] as Lang.Number) && y < (rc[1] as Lang.Number) + (rc[3] as Lang.Number)) {
                return i;
            }
        }
        return -1;
    }

    function flashAndOpen(i as Lang.Number) as Void {
        if (flashIdx >= 0) {
            return;
        }
        focus = i;
        flashIdx = i;
        Feedback.tick();
        WatchUi.requestUpdate();
        if (_flashTimer == null) {
            _flashTimer = new Timer.Timer();
        }
        (_flashTimer as Timer.Timer).start(method(:onFlashDone), Feedback.FLASH_MS, false);
    }

    function onFlashDone() as Void {
        flashIdx = -1;
        open();
    }

    //! Flipper: OK applies the filter -> book list headed "< X >".
    function open() as Void {
        var books = PickList.booksForFilter(focus);
        var title = focus == 0 ? "All books" : (focus >= 19 ? "Numbered books" : "Books: " + PickList.FILTER_LABELS[focus]);
        var v = new PickListView(title, PickList.bookLabels(books));
        WatchUi.pushView(v, new PickListDelegate(v, 0, books), WatchUi.SLIDE_LEFT);
    }
}

class FilterGridDelegate extends WatchUi.BehaviorDelegate {
    var _view as FilterGridView;

    function initialize(view as FilterGridView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Lang.Boolean {
        _view.focus = (_view.focus + 1) % PickList.FILTER_LABELS.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        var n = PickList.FILTER_LABELS.size();
        _view.focus = (_view.focus + n - 1) % n;
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Lang.Boolean {
        return false; // TAP FIX: Enter via onKey, taps via onTap
    }

    function onKey(evt as WatchUi.KeyEvent) as Lang.Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            _view.open();
            return true;
        }
        return false;
    }

    function onTap(evt as WatchUi.ClickEvent) as Lang.Boolean {
        var c = evt.getCoordinates();
        var i = _view.indexAt(c[0], c[1]);
        if (i >= 0) {
            _view.flashAndOpen(i);
        }
        return true;
    }

    function onSwipe(evt) as Lang.Boolean {
        if (evt.getDirection() == WatchUi.SWIPE_RIGHT) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return true; // swipes never move focus twice (behavior already did)
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
