using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;

//! Home rows: 66 books, then one "Menu & Settings" row (v6: the app menu is reachable
//! without knowing the hold-UP / MENU gesture). Up from Genesis wraps straight onto it.
const HOME_ROWS = 67;
const HOME_MENU_ROW = 66;

class BookListView extends WatchUi.View {
    var focus as Lang.Number = 0; // 0..65 = book (Genesis..Revelation), 66 = menu row
    // Hit-test cache from last onUpdate
    var _rowTop as Lang.Number = 0;
    var _rowH as Lang.Number = 0;
    var _rowCount as Lang.Number = 0;
    var _labels as Lang.Array or Null = null;

    function initialize() {
        View.initialize();
        focus = AppState.selectedBook; // last-read book (LastReadApp.restore)
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var t0 = Perf.start();
        onUpdateImpl(dc);
        Perf.end("books", t0);
    }

    function onUpdateImpl(dc as Graphics.Dc) as Void {
        // Flipper home "< All >": every book, scrolling round list (full BSB bundled).
        // PERF: label array built once (same array -> PickList layout cache hits).
        if (_labels == null) {
            var labels = [] as Lang.Array;
            var i;
            for (i = 0; i < Books.BOOK_COUNT; i++) {
                labels.add(Books.name(i));
            }
            labels.add(PickList.MENU_ROW_LABEL);
            _labels = labels;
        }
        _rowCount = HOME_ROWS;
        focus = PickList.takeFocus(focus, _labels as Lang.Array);
        PickList.draw(dc, "Bible BSB", _labels as Lang.Array, focus);
        MenuHint.draw(dc, PickList.lastBottom);
    }

    function onShow() as Void {
        PickList.dropBitmaps(); // cached rows may be blank after views above used the pool
        Feedback.refresh(); // pick up a changed watch vibration setting / our Settings
        Nav.takeLaunch(); // first show after launch: jump to the last-read verse (once)
    }

    function onHide() as Void {
        PickList.stopWarm();
    }

    function rowAtY(y as Lang.Number) as Lang.Number {
        return PickList.indexAtY(y, HOME_ROWS);
    }

    function openFocusedBook() as Void {
        if (focus >= Books.BOOK_COUNT) {
            HomeMenu2Delegate.open();
            return;
        }
        PickList.openBook(focus);
    }
}

class BookListDelegate extends WatchUi.BehaviorDelegate {
    var _keys as KeyHold;

    function initialize() {
        BehaviorDelegate.initialize();
        _keys = new KeyHold(null, null, method(:repeatDown)); // critique #1: hold DOWN repeats
    }

    function onKeyPressed(evt as WatchUi.KeyEvent) as Lang.Boolean {
        _keys.pressed(evt.getKey());
        return false;
    }

    function onKeyReleased(evt as WatchUi.KeyEvent) as Lang.Boolean {
        _keys.released(evt.getKey());
        return false;
    }

    function repeatDown() as Void {
        onNextPage();
    }

    function view() as BookListView {
        return WatchUi.getCurrentView()[0] as BookListView;
    }

    function onNextPage() as Lang.Boolean {
        if (PickList.swallowSwipe()) {
            return true;
        }
        if (TouchGuard.consumePage()) {
            return true;
        }
        var v = view();
        v.focus = (v.focus + 1) % HOME_ROWS;
        Feedback.step();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        if (PickList.swallowSwipe()) {
            return true;
        }
        if (TouchGuard.consumePage()) {
            return true;
        }
        var v = view();
        v.focus = (v.focus + HOME_ROWS - 1) % HOME_ROWS;
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
            return activate();
        }
        return false;
    }

    function activate() as Lang.Boolean {
        view().openFocusedBook();
        return true;
    }

    function onDrag(evt as WatchUi.DragEvent) as Lang.Boolean {
        return PickList.onDrag(evt);
    }

    function onTap(evt) as Lang.Boolean {
        var coords = evt.getCoordinates();
        var v = view();
        if (coords[1] < PickList.lastTop || coords[1] >= MenuHint.footTop) {
            // Touch: the "Bible BSB" title, or the "Tap here for menu" footer, opens the menu.
            MenuHint.markSeen();
            HomeMenu2Delegate.open();
            return true;
        }
        var idx = v.rowAtY(coords[1]);
        if (idx >= 0) {
            v.focus = idx;
            v.openFocusedBook();
        }
        return true;
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        if (PickList.swallowSwipe() && (dir == WatchUi.SWIPE_UP || dir == WatchUi.SWIPE_DOWN)) {
            return true; // the drag already moved the list
        }
        if (dir == WatchUi.SWIPE_LEFT) {
            // Flipper home Right = Filter. Critique #9: the filter is now Go to…'s letter list.
            GoTo.open();
            return true;
        }
        if (dir == WatchUi.SWIPE_UP) {
            TouchGuard.markPage();
            var v = view();
            v.focus = (v.focus + 1) % HOME_ROWS;
            Feedback.step();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            TouchGuard.markPage();
            var v2 = view();
            v2.focus = (v2.focus + HOME_ROWS - 1) % HOME_ROWS;
            Feedback.step();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            TouchGuard.markBack();
            Nav.pop(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onMenu() as Lang.Boolean {
        // MENU (hold UP on Enduro/Forerunner; hold the lower button on touch watches).
        // Flipper home: Left = Collection, Right = Testament / Filter -> one app menu.
        MenuHint.markSeen();
        HomeMenu2Delegate.open();
        return true;
    }

    function onBack() as Lang.Boolean {
        if (TouchGuard.consumeBack()) {
            return true;
        }
        Nav.pop(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

//! v7 (Dylan: "no indicator for where to press/hold"): Garmin-style button hint on the home
//! screen. A short gold arc on the bezel beside the button that opens the menu, with a small
//! three-line menu mark inside it, plus a one-line footer ("Hold UP for menu" / "Tap here for
//! menu") until the menu has been opened that way once. The arc and mark stay.
module MenuHint {
    // POKE: MENU_HINT_SEEN — Storage flag: footer text hidden after the first hold/tap open.
    const SEEN_KEY = "menuHint";
    // POKE: MENU_HINT_ANGLE — bezel angle (deg, CCW from 3 o'clock) of the menu button:
    // UP/MENU at 9 o'clock on Enduro / Forerunner; the lower-right button on round
    // touch-only watches (vivoactive 5 / Venu 3, ~40 deg below horizontal).
    const ANGLE_UP = 180;
    const ANGLE_LOWER_RIGHT = 320;
    const ARC_SPAN = 9;      // half-span of the bezel arc, degrees
    const ARC_PEN = 4;

    const KIND_UP = 0;        // button watch: hold UP
    const KIND_ROUND_TOUCH = 1;
    const KIND_RECT_TOUCH = 2; // Venu Sq 2: right edge, upper button

    var _kind as Lang.Number = -1;
    var _seen as Lang.Boolean or Null = null;
    var footTop as Lang.Number = 100000; // taps at/below this y open the menu
    var _footBmp = null;
    var _footBg as Lang.Number = -1;
    var _footW as Lang.Number = 0;

    function kind() as Lang.Number {
        if (_kind < 0) {
            var ds = System.getDeviceSettings();
            if (ds.screenShape == System.SCREEN_SHAPE_RECTANGLE) {
                _kind = KIND_RECT_TOUCH;
            } else if ((ds has :inputButtons) && (ds.inputButtons & System.BUTTON_INPUT_UP) == 0) {
                _kind = KIND_ROUND_TOUCH;
            } else {
                _kind = KIND_UP;
            }
            Perf.note("MENU HINT kind=" + _kind);
        }
        return _kind;
    }

    function label() as Lang.String {
        return kind() == KIND_UP ? "Hold UP for menu" : "Tap here for menu";
    }

    function seen() as Lang.Boolean {
        if (_seen == null) {
            _seen = Application.Storage.getValue(SEEN_KEY) == true;
        }
        return _seen as Lang.Boolean;
    }

    function markSeen() as Void {
        if (!seen()) {
            _seen = true;
            Application.Storage.setValue(SEEN_KEY, true);
        }
    }

    var _markBmp = null;
    var _markBg as Lang.Number = -1;
    var _mx as Lang.Number = 0; // mark bitmap origin on screen
    var _my as Lang.Number = 0;
    var _mw as Lang.Number = 0;
    var _mh as Lang.Number = 0;
    var _sw as Lang.Number = 0;
    var _sh as Lang.Number = 0;

    function draw(dc as Graphics.Dc, listBottom as Lang.Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        // The mark is painted once into a small bitmap (box around arc + glyph) and blitted.
        if (_markBmp == null || _markBg != Palette.BG
            || (_markBmp as Graphics.BufferedBitmapReference).get() == null) {
            _sw = w;
            _sh = h;
            markBox(w, h);
            _markBmp = MenuBmp.render(_mw, _mh, new Lang.Method(MenuHint, :paintMarkBmp));
            _markBg = Palette.BG;
        }
        if (_markBmp != null) {
            dc.drawBitmap(_mx, _my, _markBmp as Graphics.BufferedBitmapReference);
        } else {
            paintMark(dc, 0, 0);
        }
        if (seen()) {
            footTop = listBottom + 6; // the footer area still opens the menu on touch
            return;
        }
        drawFooter(dc, w, listBottom + 6);
    }

    //! Screen box (x, y, w, h) holding the bezel arc and the menu glyph.
    function markBox(w as Lang.Number, h as Lang.Number) as Void {
        var k = kind();
        if (k == KIND_RECT_TOUCH) {
            var by = (h * 0.22).toNumber();
            _mx = w - 24;
            _my = by - 16;
            _mw = 24;
            _mh = 32;
            return;
        }
        var cx = w / 2;
        var cy = h / 2;
        var r = (w < h ? w : h) / 2;
        var a = k == KIND_UP ? ANGLE_UP : ANGLE_LOWER_RIGHT;
        var x0 = w;
        var y0 = h;
        var x1 = 0;
        var y1 = 0;
        var pts = [[r, a - ARC_SPAN], [r, a + ARC_SPAN], [r, a], [r - 23, a], [r - 11, a]] as Lang.Array;
        var i;
        for (i = 0; i < pts.size(); i++) {
            var p = pts[i] as Lang.Array;
            var rad = Math.toRadians(p[1] as Lang.Number);
            var x = cx + ((p[0] as Lang.Number) * Math.cos(rad)).toNumber();
            var y = cy - ((p[0] as Lang.Number) * Math.sin(rad)).toNumber();
            x0 = x < x0 ? x : x0;
            y0 = y < y0 ? y : y0;
            x1 = x > x1 ? x : x1;
            y1 = y > y1 ? y : y1;
        }
        _mx = x0 - 7;
        _my = y0 - 7;
        _mw = x1 - x0 + 14;
        _mh = y1 - y0 + 14;
    }

    function paintMarkBmp(dc as Graphics.Dc) as Void {
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        paintMark(dc, _mx, _my);
    }

    //! Bezel arc beside the menu button + three-line menu glyph; (ox, oy) = dc origin on screen.
    function paintMark(dc as Graphics.Dc, ox as Lang.Number, oy as Lang.Number) as Void {
        var w = _sw;
        var h = _sh;
        var k = kind();
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        var gx;
        var gy;
        if (k == KIND_RECT_TOUCH) {
            // POKE: MENU_HINT_RECT_Y — upper right button on Venu Sq 2 (hold = menu).
            var by = (h * 0.22).toNumber();
            dc.fillRectangle(w - ARC_PEN - ox, by - 14 - oy, ARC_PEN, 28);
            gx = w - 16;
            gy = by;
        } else {
            var cx = w / 2;
            var cy = h / 2;
            var r = (w < h ? w : h) / 2;
            var a = k == KIND_UP ? ANGLE_UP : ANGLE_LOWER_RIGHT;
            dc.setPenWidth(ARC_PEN);
            dc.drawArc(cx - ox, cy - oy, r - ARC_PEN / 2 - 1, Graphics.ARC_COUNTER_CLOCKWISE, a - ARC_SPAN, a + ARC_SPAN);
            dc.setPenWidth(1);
            var rad = Math.toRadians(a);
            var gr = r - 17;
            gx = cx + (gr * Math.cos(rad)).toNumber();
            gy = cy - (gr * Math.sin(rad)).toNumber();
        }
        // Three-line menu mark (Garmin's own "menu" glyph shape), centred on (gx, gy).
        var i;
        for (i = -1; i <= 1; i++) {
            dc.fillRectangle(gx - 5 - ox, gy + i * 4 - 1 - oy, 10, 2);
        }
    }

    //! Footer text, rendered once into a bitmap (no per-frame text raster on the home list).
    function drawFooter(dc as Graphics.Dc, w as Lang.Number, y as Lang.Number) as Void {
        footTop = y;
        var f = Graphics.FONT_XTINY;
        var t = label();
        if (_footBmp == null || _footBg != Palette.BG
            || (_footBmp as Graphics.BufferedBitmapReference).get() == null) {
            _footW = dc.getTextWidthInPixels(t, f) + 4;
            _footBmp = MenuBmp.render(_footW, dc.getFontHeight(f), new Lang.Method(MenuHint, :paintFooter));
            _footBg = Palette.BG;
        }
        if (_footBmp != null) {
            dc.drawBitmap(w / 2 - _footW / 2, y, _footBmp as Graphics.BufferedBitmapReference);
        } else {
            dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, f, t, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function paintFooter(dc as Graphics.Dc) as Void {
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, 0, Graphics.FONT_XTINY, label(), Graphics.TEXT_JUSTIFY_CENTER);
    }
}
