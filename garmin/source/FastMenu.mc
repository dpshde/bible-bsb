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
        var n = items.size();
        if (n == 0) {
            return;
        }
        var f = focus + d;
        if (f < 0) {
            f = FastMenuPoke.WRAP ? n - 1 : 0;
        } else if (f >= n) {
            f = FastMenuPoke.WRAP ? 0 : n - 1;
        }
        if (f == focus) {
            return;
        }
        focus = f;
        noteFocus();
        WatchUi.requestUpdate();
    }

    function noteFocus() as Void {
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
            }
        }
        probe(t0, paints);
        warmSoon();
    }

    (:debug)
    function probe(t0 as Lang.Number, paints as Lang.Number) as Void {
        System.println("FAST ms=" + (System.getTimer() - t0) + " paints=" + paints + " t=" + System.getTimer());
    }

    (:release)
    function probe(t0 as Lang.Number, paints as Lang.Number) as Void {
    }

    //! Same title as P1Menu.drawTitle / ThemedMenu.paintTitle (their dc is the space above row 0).
    function drawTitle(dc as Graphics.Dc, w as Lang.Number, bottom as Lang.Number) as Void {
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

    function initialize(menu as FastMenu, inner) {
        BehaviorDelegate.initialize();
        _menu = menu;
        _inner = inner;
    }

    function onNextPage() as Lang.Boolean {
        if (TouchGuard.consumePage()) {
            return true;
        }
        _menu.step(1);
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
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

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP || dir == WatchUi.SWIPE_DOWN) {
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
