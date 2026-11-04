using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

//! 0.9.6 (Dylan, real Enduro 3: "menu nav up and down animation is slow, much snappier").
//! WatchUi.CustomMenu slides every step with a firmware animation that has no speed setting and
//! repaints every visible row on every animation frame (Enduro 3: vector-font text each time).
//! FastMenu is a plain View laid out exactly like that CustomMenu (focused row centred, title
//! above row 0, same item width / left gutter, same rows: they paint into an item-sized bitmap),
//! but a step is one redraw of cached row bitmaps: no slide, no text drawn on a step once warm.
//! Same Menu2 calls the app uses (addItem, getItem, findItemById, setFocus, getFocus, size) and
//! the screen's own Menu2InputDelegate (onSelect(item), onBack) via FastMenuDelegate.
//! POKE: UiMenu.MENU_FAST (ThemedMenu.mc) false = back to the 0.9.5 CustomMenu.
//! Poke points for FastMenu (module consts, so tests and callers can read them).
module FastMenuPoke {
    // POKE: FAST_WRAP — UP on the first row goes to the last (and DOWN on the last to the first).
    const WRAP = true;
    // POKE: FAST_CACHE — row bitmaps kept (focused and plain states count separately). About
    // two screens' worth; older ones are dropped (and the system may purge any of them).
    const CACHE = 14;
    // POKE: FAST_WARM_MS — after a step, the rows the next step will need are painted this long
    // later (idle), so the next press is pure bitmap copies. 0 = no warm-up.
    const WARM_MS = 60;
    // POKE: MARQUEE_* (0.9.8) — the focused row's label / sublabel that end in "…" scroll
    // sideways: wait DELAY, STEP_PX every TICK_MS, hold END_MS at the end, jump back, repeat.
    const MARQUEE_DELAY_MS = 1000;
    const MARQUEE_TICK_MS = 50;
    const MARQUEE_STEP_PX = 3;
    const MARQUEE_END_MS = 1000;
}

class FastMenu extends WatchUi.View {
    var title as Lang.String;
    var items as Lang.Array = [] as Lang.Array;
    var focus as Lang.Number = 0;
    var rowH as Lang.Number;
    var themed as Lang.Boolean; // ThemedMenu title style (gold title, wider rule)
    var _cache as Lang.Dictionary = {}; // item index * 2 + focused -> [ref, lastUse]
    var _use as Lang.Number = 0;
    var _rev as Lang.Number = -1;
    var _bg as Lang.Number = -1;
    var _pItem = null;
    var _pFocused as Lang.Boolean = false;
    var _timer as Timer.Timer or Null = null;
    var lastTop as Lang.Number = 0; // y of row 0 in the last frame (taps)

    function initialize(t as Lang.String, rowHeight as Lang.Number, themedTitle as Lang.Boolean) {
        View.initialize();
        title = t;
        rowH = rowHeight;
        themed = themedTitle;
    }

    // ---- Menu2 calls the app makes ---------------------------------------------------------
    function addItem(item) as Void {
        items.add(item);
    }

    function getItem(i as Lang.Number) {
        return i >= 0 && i < items.size() ? items[i] : null;
    }

    function size() as Lang.Number {
        return items.size();
    }

    function findItemById(id) as Lang.Number {
        if (id == null) {
            return -1;
        }
        for (var i = 0; i < items.size(); i++) {
            var iid = (items[i] as WatchUi.MenuItem).getId();
            if (iid != null && iid.equals(id)) {
                return i;
            }
        }
        return -1;
    }

    function setFocus(i as Lang.Number) as Void {
        focus = i < 0 ? 0 : (i >= items.size() ? (items.size() > 0 ? items.size() - 1 : 0) : i);
        noteFocus();
    }

    function getFocus() as Lang.Number {
        return focus;
    }

    function focusedItem() {
        return getItem(focus);
    }

    // ---- Geometry (matches WatchUi.CustomMenu on enduro3 / fr265) --------------------------
    //! CustomMenu's item dc starts right of a system focus gutter: enduro3 280 -> 243 px wide,
    //! fr265 416 -> 367 (measured in the 0.9.5 sim build). POKE: FAST_GUTTER for other sizes.
    static function gutter() as Lang.Number {
        var sw = MeasureDc.screenW();
        if (sw == 280) {
            return 37;
        }
        if (sw == 416) {
            return 49;
        }
        return (sw * 0.125).toNumber();
    }

    function rowTop(dc as Graphics.Dc, i as Lang.Number) as Lang.Number {
        return (dc.getHeight() - rowH) / 2 + (i - focus) * rowH; // CustomMenu: (h - row) / 2
    }

    //! Row index under screen y, or -1 (title / empty space).
    function rowAt(y as Lang.Number) as Lang.Number {
        if (y < lastTop) {
            return -1;
        }
        var i = (y - lastTop) / rowH;
        return i < items.size() ? i : -1;
    }

    // ---- Steps -----------------------------------------------------------------------------
    function step(d as Lang.Number) as Void {
        stepWrap(d, FastMenuPoke.WRAP);
    }

    function stepWrap(d as Lang.Number, wrap as Lang.Boolean) as Void {
        var n = items.size();
        if (n == 0) {
            return;
        }
        var f = focus + d;
        if (f < 0) {
            f = wrap ? n - 1 : 0;
        } else if (f >= n) {
            f = wrap ? 0 : n - 1;
        }
        if (f == focus) {
            return;
        }
        focus = f;
        noteFocus();
        WatchUi.requestUpdate();
    }

    // ---- Marquee (0.9.8): focused row only; a step resets it so scrolling stays cached ------
    var _mqTimer as Timer.Timer or Null = null;
    var _mqItem = null;
    var _mqEnd as Lang.Boolean = false;

    // 0.9.8e (Dylan, real Enduro 3: Bookmarks laggy over range rows): a marquee frame was a
    // fresh row repaint (vector-font text) every 50 ms. Now each overflowing line is painted
    // ONCE into a wide strip; a frame = cached row + clipped strip blits.
    var _strips as Lang.Array or Null = null; // [[ref, y, h, over]...] for _mqItem

    function buildStrips() as Void {
        _strips = [] as Lang.Array;
        var g = _mqItem != null ? _mqItem.mqGeo() : null;
        if (g == null) {
            return;
        }
        var lines = (g as Lang.Array)[2] as Lang.Array;
        for (var k = 0; k < lines.size(); k++) {
            var ln = lines[k] as Lang.Array;
            _pLine = ln;
            var ref = MenuBmp.render(((g as Lang.Array)[1] as Lang.Number) + (ln[4] as Lang.Number) + 4,
                                     ln[3] as Lang.Number, method(:paintLine));
            _pLine = null;
            if (ref != null) {
                (_strips as Lang.Array).add([ref, ln[2], ln[3], ln[4]]);
            }
        }
    }

    var _pLine = null;

    function paintLine(dc as Graphics.Dc) as Void {
        var ln = _pLine as Lang.Array;
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        dc.setColor(ln[5] as Lang.Number, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, 0, ln[0] as Graphics.FontType, ln[1] as Lang.String, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawStrips(dc as Graphics.Dc, gx as Lang.Number, y as Lang.Number) as Void {
        if (_strips == null) {
            buildStrips();
        }
        var g = _mqItem.mqGeo();
        if (g == null) {
            return;
        }
        var tx = gx + ((g as Lang.Array)[0] as Lang.Number);
        var room = (g as Lang.Array)[1] as Lang.Number;
        var off = _mqItem.mq as Lang.Number;
        var ss = _strips as Lang.Array;
        for (var k = 0; k < ss.size(); k++) {
            var s = ss[k] as Lang.Array;
            var ref = s[0] as Graphics.BufferedBitmapReference;
            if (ref.get() == null) {
                continue;
            }
            var ly = y + (s[1] as Lang.Number);
            var lh = s[2] as Lang.Number;
            var over = s[3] as Lang.Number;
            dc.setClip(tx, ly, room, lh);
            dc.drawBitmap(tx - (off < over ? off : over), ly, ref);
            dc.clearClip();
        }
    }

    function mqStop() as Void {
        _strips = null;
        if (_mqTimer != null) {
            (_mqTimer as Timer.Timer).stop();
        }
        if (_mqItem != null) {
            _mqItem.mq = 0;
            _mqItem = null;
        }
    }

    function mqKick() as Void {
        mqStop();
        var it = focusedItem();
        if (it != null && (it has :mq)) {
            _mqItem = it;
            _mqEnd = false;
            if (_mqTimer == null) {
                _mqTimer = new Timer.Timer();
            }
            (_mqTimer as Timer.Timer).start(method(:mqTick), FastMenuPoke.MARQUEE_DELAY_MS, false);
        }
    }

    function mqTick() as Void {
        var it = _mqItem;
        if (it == null || WatchUi.getCurrentView()[0] != me || it != focusedItem()) {
            mqStop();
            return;
        }
        var over = it.mqOver() as Lang.Number;
        if (over <= 0) {
            _mqItem = null; // fits (or not laid out yet): nothing to scroll
            return;
        }
        var t = _mqTimer as Timer.Timer;
        if (_mqEnd) { // end pause over: back to the start, wait, go again
            _mqEnd = false;
            it.mq = 0;
            t.start(method(:mqTick), FastMenuPoke.MARQUEE_DELAY_MS, false);
        } else {
            it.mq = it.mq + FastMenuPoke.MARQUEE_STEP_PX;
            if (it.mq >= over) {
                it.mq = over;
                _mqEnd = true;
                t.start(method(:mqTick), FastMenuPoke.MARQUEE_END_MS, false);
            } else {
                t.start(method(:mqTick), FastMenuPoke.MARQUEE_TICK_MS, false);
            }
        }
        WatchUi.requestUpdate();
    }

    function onShow() as Void {
        mqKick();
    }

    function onHide() as Void {
        mqStop();
    }

    function noteFocus() as Void {
        mqKick();
        var it = focusedItem();
        if (it != null) {
            UiMenu.lastFocusId = (it as WatchUi.MenuItem).getId();
        }
    }

    // ---- Drawing ---------------------------------------------------------------------------
    function onUpdate(dc as Graphics.Dc) as Void {
        var t0 = Perf.now();
        if (Perf.navT != 0) {
            Perf.navPaint("menu " + title);
        }
        if (_rev != UiMenu.rowRev || _bg != Palette.BG) {
            _cache = {}; // a label / sublabel / toggle / theme changed: repaint rows
            _rev = UiMenu.rowRev;
            _bg = Palette.BG;
        }
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        var top = rowTop(dc, 0);
        lastTop = top;
        if (top > 0) {
            drawTitle(dc, w, top);
        }
        var gx = gutter();
        var iw = w - gx;
        var paints = 0;
        var first = focus - (h / 2) / rowH - 1;
        var last = focus + (h / 2) / rowH + 1;
        for (var i = (first < 0 ? 0 : first); i <= last && i < items.size(); i++) {
            var y = top + i * rowH;
            if (y + rowH <= 0 || y >= h) {
                continue;
            }
            var had = _cache[i * 2 + (i == focus ? 1 : 0)] != null;
            var ref = rowBmp(i, i == focus, iw);
            if (ref != null) {
                if (!had) {
                    paints++;
                }
                dc.drawBitmap(gx, y, ref as Graphics.BufferedBitmapReference);
                if (i == focus && _mqItem != null && _mqItem.mq > 0) {
                    drawStrips(dc, gx, y);
                }
            }
        }
        probe(t0, paints);
        warmSoon();
    }



    (:debug)
    function probe(t0 as Lang.Number, paints as Lang.Number) as Void {
        System.println("FAST ms=" + (System.getTimer() - t0) + " paints=" + paints + " f=" + focus
            + " mq=" + (_mqItem != null ? _mqItem.mq : -1) + " t=" + System.getTimer());
        Perf.touchFrame("menu", t0);
    }

    (:release)
    function probe(t0 as Lang.Number, paints as Lang.Number) as Void {
    }

    //! Same title as P1Menu.drawTitle / ThemedMenu.paintTitle (their dc is the space above row 0).
    function drawTitle(dc as Graphics.Dc, w as Lang.Number, bottom as Lang.Number) as Void {
        drawHeader(dc, w, bottom, title, themed);
    }

    //! 0.9.8d: THE menu header (text + divider rule), shared with the home list (PickList).
    static function drawHeader(dc as Graphics.Dc, w as Lang.Number, bottom as Lang.Number,
                               title as Lang.String, themed as Lang.Boolean) as Void {
        var f = Zoom.MENU_TITLE_FONT;
        dc.setColor(themed ? Palette.GOLD : Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        Faces.drawHead(dc, w / 2, bottom - dc.getFontHeight(f) - 5, f, title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(themed ? Palette.DIVIDER_RULE : Palette.DIVIDER, Graphics.COLOR_TRANSPARENT);
        var m = themed ? w / 6 : w / 5;
        dc.drawLine(m, bottom - 2, w - m, bottom - 2);
    }

    //! Row i in one state, painted once into an item-sized bitmap (row's own paint(dc, focused)).
    function rowBmp(i as Lang.Number, focused as Lang.Boolean, iw as Lang.Number) {
        var key = i * 2 + (focused ? 1 : 0);
        _use++;
        var e = _cache[key];
        if (e != null) {
            var r = (e as Lang.Array)[0];
            if ((r as Graphics.BufferedBitmapReference).get() != null) {
                (e as Lang.Array)[1] = _use;
                return r;
            }
        }
        trim();
        _pItem = items[i];
        _pFocused = focused;
        var ref = MenuBmp.render(iw, rowH, method(:paintPending));
        if (ref == null && _cache.size() > 0) {
            _cache = {}; // graphics pool full: drop every row and try once more
            ref = MenuBmp.render(iw, rowH, method(:paintPending));
        }
        _pItem = null;
        if (ref != null) {
            _cache[key] = [ref, _use];
        } else {
            Perf.note("FastMenu: no row bitmap");
        }
        return ref;
    }

    function paintPending(dc as Graphics.Dc) as Void {
        var it = _pItem;
        if (it != null) {
            it.paint(dc, _pFocused);
        }
    }

    //! Keep at most FastMenuPoke.CACHE bitmaps: drop the least recently drawn.
    function trim() as Void {
        while (_cache.size() >= FastMenuPoke.CACHE) {
            var ks = _cache.keys();
            var oldK = null;
            var oldU = 0;
            for (var k = 0; k < ks.size(); k++) {
                var u = (_cache[ks[k]] as Lang.Array)[1] as Lang.Number;
                if (oldK == null || u < oldU) {
                    oldK = ks[k];
                    oldU = u;
                }
            }
            _cache.remove(oldK);
        }
    }

    // ---- Idle warm-up: the next step's new states ------------------------------------------
    function warmSoon() as Void {
        if (FastMenuPoke.WARM_MS <= 0 || items.size() < 2) {
            return;
        }
        if (_timer == null) {
            _timer = new Timer.Timer();
        } else {
            (_timer as Timer.Timer).stop();
        }
        (_timer as Timer.Timer).start(method(:warm), FastMenuPoke.WARM_MS, false);
    }

    function warm() as Void {
        if (WatchUi.getCurrentView()[0] != me) {
            return;
        }
        var iw = MeasureDc.screenW() - gutter();
        var n = items.size();
        var span = MeasureDc.screenH() / 2 / rowH + 1; // rows above / below focus on screen
        // Focused neighbours, the current row unfocused, and the rows that scroll into view.
        var want = [[focus + 1, true], [focus - 1, true], [focus, false],
                    [focus + span, false], [focus - span, false]] as Lang.Array;
        for (var k = 0; k < want.size(); k++) {
            var p = want[k] as Lang.Array;
            var i = p[0] as Lang.Number;
            if (FastMenuPoke.WRAP) {
                i = (i % n + n) % n;
            }
            if (i >= 0 && i < n) {
                rowBmp(i, p[1] as Lang.Boolean, iw);
            }
        }
    }
}

//! Buttons and touch for a FastMenu, handed to the screen's own Menu2InputDelegate.
//! Touch follows BookListDelegate: a tap also arrives as onSelect (ignored; onKey takes START),
//! a swipe also arrives as onNextPage / onBack (TouchGuard drops the repeat).
class FastMenuDelegate extends WatchUi.BehaviorDelegate {
    var _menu as FastMenu;
    var _inner;
    var _drag as DragStep;

    function initialize(menu as FastMenu, inner) {
        BehaviorDelegate.initialize();
        _menu = menu;
        _inner = inner;
        // 0.9.7: the list follows the finger, one row per row height of travel (no wrap mid-drag).
        _drag = new DragStep(method(:dragStep), menu.rowH);
    }






    function dragStep(d as Lang.Number) as Void {
        _menu.stepWrap(d, false);
    }

    function onNextPage() as Lang.Boolean {
        if (_drag.swallow()) {
            return true;
        }
        if (TouchGuard.consumePage()) {
            return true;
        }
        _menu.step(1);
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        if (_drag.swallow()) {
            return true;
        }
        if (TouchGuard.consumePage()) {
            return true;
        }
        _menu.step(-1);
        return true;
    }

    function onSelect() as Lang.Boolean {
        return false;
    }

    function onKey(evt as WatchUi.KeyEvent) as Lang.Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            activate();
            return true;
        }
        return false;
    }

    function activate() as Void {
        var it = _menu.focusedItem();
        if (it != null) {
            _inner.onSelect(it);
        }
    }

    function onTap(evt) as Lang.Boolean {
        var i = _menu.rowAt((evt.getCoordinates() as Lang.Array)[1] as Lang.Number);
        if (i >= 0) {
            _menu.setFocus(i);
            WatchUi.requestUpdate();
            activate();
        }
        return true;
    }

    function onDrag(evt as WatchUi.DragEvent) as Lang.Boolean {
        return _drag.onDrag(evt);
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP || dir == WatchUi.SWIPE_DOWN) {
            if (_drag.swallow()) {
                return true; // the drag already moved the list
            }
            TouchGuard.markPage();
            _menu.step(dir == WatchUi.SWIPE_UP ? 1 : -1);
            return true;
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            TouchGuard.markBack();
            _inner.onBack();
            return true;
        }
        return false;
    }

    function onBack() as Lang.Boolean {
        if (TouchGuard.consumeBack()) {
            return true;
        }
        _inner.onBack();
        return true;
    }
}
