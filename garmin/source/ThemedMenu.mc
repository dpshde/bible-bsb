using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

//! POKE: MENU_THEME — native Menu2 is system-themed (always dark), so every app menu is a
//! CustomMenu drawn with Palette (follows Dark/Light). Same Menu2InputDelegate API.
class ThemedMenu extends WatchUi.CustomMenu {
    var _title as Lang.String;
    var _titleBmp = null;      // v7: title rendered once, then blitted
    var _titleBg as Lang.Number = -1;
    var items as Lang.Array = [] as Lang.Array; // our rows, for the idle pre-paint (MenuWarm)

    function initialize(title as Lang.String) {
        var h = MeasureDc.screenH();
        // POKE: MENU_ROW_H — 30% rows: only the rows above/below focus are on screen, both
        // where the circle is still wide, so no row runs into the bezel.
        var row = (h * Zoom.THEMED_ROW_FRAC).toNumber();
        CustomMenu.initialize(row, Palette.BG, {
            :focusItemHeight => row,
            :titleItemHeight => (h * Zoom.THEMED_TITLE_FRAC).toNumber(),
            :foreground => new MenuFocusMask(row)
        });
        _title = title;
    }

    function addItem(item as WatchUi.CustomMenuItem) as Void {
        CustomMenu.addItem(item);
        items.add(item);
    }

    function drawTitle(dc as Graphics.Dc) as Void {
        Perf.navPaint("themed menu");
        MenuWarm.start(me);
        var t0 = Perf.now();
        var ref = _titleBmp;
        if (ref == null || _titleBg != Palette.BG || (ref as Graphics.BufferedBitmapReference).get() == null) {
            ref = MenuBmp.render(dc.getWidth(), dc.getHeight(), method(:paintTitle));
            _titleBmp = ref;
            _titleBg = Palette.BG;
        }
        if (ref != null) {
            dc.drawBitmap(0, 0, ref as Graphics.BufferedBitmapReference);
        } else {
            paintTitle(dc);
        }
        Perf.lite("mtitle", t0);
    }

    function paintTitle(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        var f = Zoom.MENU_TITLE_FONT;
        Faces.drawHead(dc, w / 2, h - dc.getFontHeight(f) - 5, f, _title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Palette.DIVIDER_RULE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(w / 6, h - 2, w - w / 6, h - 2);
    }
}

//! v7 PERF: after a ThemedMenu's first frame, one Timer paints every row's focused and
//! dimmed bitmaps in slices of at most BUDGET_MS, so even the first press on a row is a blit.
module MenuWarm {
    const TICK_MS = 50;
    const BUDGET_MS = 8;
    var _menu = null;
    var _timer = null;
    var w as Lang.Number = 0; // row size, from the first row the menu drew
    var h as Lang.Number = 0;

    function start(menu as ThemedMenu) as Void {
        if (_menu == menu) {
            return;
        }
        _menu = menu;
        if (_timer == null) {
            _timer = new Timer.Timer();
        } else {
            (_timer as Timer.Timer).stop();
        }
        (_timer as Timer.Timer).start(new Lang.Method(MenuWarm, :onTick), TICK_MS, false);
    }

    function onTick() as Void {
        var m = _menu;
        if (m == null || w <= 0 || WatchUi.getCurrentView()[0] != m) {
            _menu = null; // closed (or nothing drawn yet): reopening starts again
            return;
        }
        var t0 = System.getTimer();
        var list = (m as ThemedMenu).items;
        var more = false;
        var i;
        for (i = 0; i < list.size(); i++) {
            var it = list[i];
            if (it instanceof ThemedMenuItem && !(it as ThemedMenuItem).warm(w, h)) {
                more = true;
                if (System.getTimer() - t0 >= BUDGET_MS) {
                    break;
                }
            }
        }
        Perf.idle("menu", t0);
        if (more) {
            (_timer as Timer.Timer).start(new Lang.Method(MenuWarm, :onTick), TICK_MS, false);
        }
    }
}

//! v7 PERF: custom menu rows/titles are painted once into a BufferedBitmap and blitted on
//! every later frame (the v6 Settings screen re-measured, re-wrapped and re-rasterised each
//! row's text on every press). Null when bitmaps are unavailable: callers paint directly.
module MenuBmp {
    function render(w as Lang.Number, h as Lang.Number, paint as Lang.Method) {
        if (!(Graphics has :createBufferedBitmap) || w <= 0 || h <= 0) {
            return null;
        }
        var ref = Graphics.createBufferedBitmap({:width => w, :height => h});
        var bmp = (ref as Graphics.BufferedBitmapReference).get();
        if (bmp == null) {
            return null;
        }
        paint.invoke((bmp as Graphics.BufferedBitmap).getDc());
        return ref;
    }
}

//! POKE: MENU_CENTER_X — CustomMenu item dcs start right of the system's left focus gutter
//! (~13% of the screen), so the item dc's own w/2 sits right of the screen centre (+18 px on
//! enduro3). Centre on the SCREEN instead: screen centre expressed in item-dc coordinates.
module MenuCenter {
    function cx(dc as Graphics.Dc) as Lang.Number {
        var sw = MeasureDc.screenW(); // cached: getDeviceSettings() allocates on every call
        var off = sw - dc.getWidth(); // gutter on the left
        if (off < 0) {
            off = 0;
        }
        return sw / 2 - off;
    }

    //! Widest row that stays symmetric about the screen centre inside the item dc.
    function clampRoom(dc as Graphics.Dc, room as Lang.Number) as Lang.Number {
        var max = 2 * cx(dc) - 4;
        return room < max ? room : max;
    }
}

//! Settings / touch-watch menu row. v7: one font for both states (focus = gold vs dimmed,
//! never a size change), layout measured once per row size, and each state painted once
//! into a bitmap (MenuBmp) so a press only blits.
class ThemedMenuItem extends WatchUi.CustomMenuItem {
    var _label as Lang.String;
    var _sub as Lang.String or Null;
    var _lay as Lang.Array or Null = null; // [font, rows, subRows, w, h]
    var _bmp as Lang.Dictionary = {};      // focused 0/1 -> BufferedBitmapReference
    var _bmpBg as Lang.Number = -1;
    var _paintFocused as Lang.Boolean = false;

    function initialize(label as Lang.String, sub as Lang.String or Null, id as Lang.Object) {
        CustomMenuItem.initialize(id, {});
        _label = label;
        _sub = sub;
    }

    //! Text changed (toggle flipped): measure and paint again on the next frame.
    function invalidate() as Void {
        _lay = null;
        _bmp = {};
    }

    function layout(dc as Graphics.Dc) as Lang.Array {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var lay = _lay;
        if (lay != null && lay[3] == w && lay[4] == h) {
            return lay;
        }
        // POKE: MENU_ROW_ROOM — the row's room when focused; with 30% rows the rows above and
        // below focus still sit where the chord is wider than this, so one font fits both.
        var room = MenuCenter.clampRoom(dc, (w * 0.74).toNumber());
        var f = Zoom.MENU_LABEL_FONT;
        var rows = [_label] as Lang.Array;
        if (dc.getTextWidthInPixels(_label, f) > room) {
            // Wrap to two rows (one font for both) before any "…".
            f = Zoom.MENU_LABEL_FONT;
            if (dc.getTextWidthInPixels(_label, f) > room) {
                rows = RoundLayout.wrapRows(dc, _label, f, room, 2);
            }
        }
        var subRows = _sub != null
            ? RoundLayout.wrapRows(dc, _sub as Lang.String, Graphics.FONT_XTINY, room, rows.size() > 1 ? 1 : 2)
            : [] as Lang.Array;
        lay = [f, rows, subRows, w, h];
        _lay = lay;
        return lay;
    }

    function draw(dc as Graphics.Dc) as Void {
        var t0 = Perf.now();
        var focused = isFocused();
        if (_bmpBg != Palette.BG) {
            _bmp = {};
            _bmpBg = Palette.BG;
        }
        var key = focused ? 1 : 0;
        var ref = _bmp[key];
        if (ref == null || (ref as Graphics.BufferedBitmapReference).get() == null) {
            _paintFocused = focused;
            ref = MenuBmp.render(dc.getWidth(), dc.getHeight(), method(:paintCached));
            _bmp[key] = ref;
        }
        MenuWarm.w = dc.getWidth();
        MenuWarm.h = dc.getHeight();
        if (ref != null) {
            dc.drawBitmap(0, 0, ref as Graphics.BufferedBitmapReference);
        } else {
            paint(dc, focused);
        }
        Perf.lite("mitem", t0);
    }

    //! Idle pre-paint: render one missing state at row size (w, h). True when both exist.
    function warm(w as Lang.Number, h as Lang.Number) as Lang.Boolean {
        if (_bmpBg != Palette.BG) {
            _bmp = {};
            _bmpBg = Palette.BG;
        }
        var k;
        for (k = 0; k < 2; k++) {
            var ref = _bmp[k];
            if (ref == null || (ref as Graphics.BufferedBitmapReference).get() == null) {
                _paintFocused = k == 1;
                ref = MenuBmp.render(w, h, method(:paintCached));
                if (ref == null) {
                    return true; // no bitmaps here: nothing to warm
                }
                _bmp[k] = ref;
                return false;
            }
        }
        return true;
    }

    function paintCached(dc as Graphics.Dc) as Void {
        paint(dc, _paintFocused);
    }

    function paint(dc as Graphics.Dc, focused as Lang.Boolean) as Void {
        var lay = layout(dc);
        var h = dc.getHeight();
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        var f = lay[0] as Graphics.FontDefinition;
        var rows = lay[1] as Lang.Array;
        var subRows = lay[2] as Lang.Array;
        var cx = MenuCenter.cx(dc);
        var fh = dc.getFontHeight(f);
        var lh = fh - 3;
        var sf = Graphics.FONT_XTINY;
        var sh = dc.getFontHeight(sf);
        var slh = sh - 3;
        var th = fh + (rows.size() - 1) * lh;
        var stotal = subRows.size() > 0 ? sh + (subRows.size() - 1) * slh : 0;
        var y = (h - th - stotal) / 2;
        // Focus by colour only (gold vs dimmed): same font, same size, no cards/pills.
        dc.setColor(focused ? Palette.GOLD : Palette.DIM_VERSE, Graphics.COLOR_TRANSPARENT);
        var i;
        for (i = 0; i < rows.size(); i++) {
            dc.drawText(cx, y + i * lh, f, rows[i] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        for (i = 0; i < subRows.size(); i++) {
            dc.drawText(cx, y + th + 1 + i * slh, sf, subRows[i] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

//! CustomMenu's system chrome: a teal focus slash (AMOLED) or a white bar (MIP) in a black
//! left gutter. Off-palette, so this foreground paints the theme background over the gutter.
class MenuFocusMask extends WatchUi.Drawable {
    var _fh as Lang.Number;

    function initialize(focusH as Lang.Number) {
        Drawable.initialize({});
        _fh = focusH;
    }

    function draw(dc as Graphics.Dc) as Void {
        var t0 = Perf.now();
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Palette.BG, Palette.BG);
        // POKE: MENU_MASK_W — the system keeps a left gutter (~13% of the width) for its focus
        // mark and fills it black; paint it in the theme background over the full height so
        // Light mode has no dark strip.
        dc.fillRectangle(0, 0, (w * 0.13).toNumber() + 1, h);
        Perf.lite("mmask", t0);
        Perf.rowsDone();
    }
}

//! Menu item whose label may be long (Go to verse section headings): one row if it fits,
//! else a pyramid two-row split (row 1 <= row 2), each row inside the circle chord; only
//! as a last resort row 2 ends in an ellipsis. Split cached per font (no per-frame measure).
class ThemedWrapItem extends WatchUi.CustomMenuItem {
    var _label as Lang.String;
    var _suffix as Lang.String; // " (1–25)": never cut off
    var _rows as Lang.Dictionary = {}; // focused(0/1) -> [font, rows[]]

    function initialize(title as Lang.String, suffix as Lang.String, id as Lang.Object) {
        CustomMenuItem.initialize(id, {});
        _label = title;
        _suffix = suffix;
    }

    function rowsFor(dc as Graphics.Dc, focused as Lang.Boolean) as Lang.Array {
        var key = focused ? 1 : 0;
        var c = _rows[key];
        if (c != null) {
            return c as Lang.Array;
        }
        var w = dc.getWidth();
        // POKE: GOTO_WRAP_ROOM — off-center items sit where the circle is narrower.
        var room = MenuCenter.clampRoom(dc, focused ? (w * 0.74).toNumber() : (w * 0.62).toNumber());
        var full = _label + _suffix;
        // One font per state for every row (no per-row step-down): siblings match.
        // Headings are long: both states use XTINY so a focused heading wraps exactly like its
        // neighbours (3 rows max) instead of ending in "…"; focus is shown by gold.
        var fonts = [Graphics.FONT_XTINY];
        var out = null;
        var k;
        for (k = 0; k < fonts.size() && out == null; k++) {
            var f = fonts[k] as Graphics.FontDefinition;
            if (dc.getTextWidthInPixels(full, f) <= room) {
                out = [f, [full]];
            }
        }
        var wrapFonts = fonts;
        for (k = 0; k < wrapFonts.size() && out == null; k++) {
            var f2 = wrapFonts[k] as Graphics.FontDefinition;
            var parts = RoundLayout.pyramidSplit(dc, full, f2, (room * 0.86).toNumber(), room);
            if (parts != null) {
                out = [f2, parts];
            } else {
                // A third pyramid row before any truncation (rows are 30% of the screen tall).
                var three = RoundLayout.wrapThree(dc, full, f2, (room * 0.72).toNumber(),
                                                  (room * 0.88).toNumber(), room);
                if (three != null) {
                    out = [f2, three];
                }
            }
        }
        if (out == null) {
            // Last resort: shorten the TITLE, keep the verse span whole on row 2.
            var f3 = fonts[0] as Graphics.FontDefinition;
            var sw = dc.getTextWidthInPixels(_suffix, f3);
            var p2 = RoundLayout.pyramidSplitEllipsize(dc, _label, f3, (room * 0.86).toNumber(), room - sw);
            out = [f3, [p2[0], (p2[1] as Lang.String) + _suffix]];
        }
        _rows[key] = out;
        return out as Lang.Array;
    }

    function draw(dc as Graphics.Dc) as Void {
        var h = dc.getHeight();
        var focused = isFocused();
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        var r = rowsFor(dc, focused);
        var f = r[0] as Graphics.FontDefinition;
        var rows = r[1] as Lang.Array;
        var fh = dc.getFontHeight(f);
        var lh = fh - 3;
        var total = fh + (rows.size() - 1) * lh;
        var y = (h - total) / 2;
        // Focus by colour only (gold vs dimmed), same font in both states.
        dc.setColor(focused ? Palette.GOLD : Palette.DIM_VERSE, Graphics.COLOR_TRANSPARENT);
        var cx = MenuCenter.cx(dc);
        var i;
        for (i = 0; i < rows.size(); i++) {
            dc.drawText(cx, y + i * lh, f, rows[i] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

//! v4 (Dylan 4:39 PM): app menus are native WatchUi.Menu2, so title, scroll, focus, wrap and
//! back are the system's own. POKE: MENU_STYLE — targets with Menu2 themes (API 4.1.8+) get
//! MENU_THEME_ORANGE (closest system accent to gold #C89D54); older targets fall back to the
//! minimal CustomMenu above (gold text focus, no cards/pills) with the same delegate API.
//! Native menus follow the system palette, so the app's Light theme does not tint them.
module UiMenu {
    //! POKE: MENU_NATIVE — true (5:50 PM, Dylan: keep Garmin native Menu2). Targets without
    //! Menu2 themes fall back to the gold CustomMenu below. Rows stay inside the round screen by
    //! keeping labels and sublabels short (NativeLists), since Menu2 cannot inset rows.
    const MENU_NATIVE = true;
    // POKE: MENU_P1 — true (Dylan 2:56 PM): every list is a P1Menu (native Menu2 layout, P1
    // colors, follows Dark/Light) on every target. false: Menu2 + MENU_THEME_ORANGE as before.
    const MENU_P1 = true;
    var lastFocusId = null; // id of the P1 row drawn focused last (Menu2 has no getFocus)

    function isNative() as Lang.Boolean {
        return MENU_NATIVE && MenuStyle.DARK_NATIVE && (WatchUi has :MENU_THEME_ORANGE);
    }

    function create(title as Lang.String) {
        if (MENU_P1) {
            return new P1Menu(title);
        }
        if (isNative()) {
            return new WatchUi.Menu2({:title => title, :theme => WatchUi.MENU_THEME_ORANGE});
        }
        return new ThemedMenu(title);
    }

    function item(label as Lang.String, sub as Lang.String or Null, id as Lang.Object) {
        if (MENU_P1) {
            return new P1MenuItem(label, sub, id);
        }
        if (isNative()) {
            return new WatchUi.MenuItem(label, sub, id, null);
        }
        return new ThemedMenuItem(label, sub, id);
    }

    //! A Bookmarks row: sublabel "Color · verse start". P1: the snippet is made when the row is
    //! first drawn (BookmarkItem); other menus make it now.
    function bookmark(label as Lang.String, color as Lang.String or Null, id as Lang.Number) {
        if (MENU_P1) {
            return new BookmarkItem(label, color, id);
        }
        return item(label, BookmarkItem.join(color, Snippets.of(id)), id);
    }

    //! On/off setting with a plain-language sublabel for each state.
    //! Native: ToggleMenuItem (system switch). Fallback: ThemedToggleItem (sublabel flips).
    function toggle(label as Lang.String, subOn as Lang.String, subOff as Lang.String,
                    on as Lang.Boolean, id as Lang.Object) {
        if (MENU_P1) {
            return new P1ToggleItem(label, subOn, subOff, on, id);
        }
        if (isNative()) {
            // Plain native item whose sublabel names the current state: no system switch
            // (the system draws it green on every target, and green is off-palette).
            return new StateMenuItem(label, subOn, subOff, on, id);
        }
        return new ThemedToggleItem(label, subOn, subOff, on, id);
    }

    //! State after the user selected a toggle item (native flips it itself).
    function toggledState(item) as Lang.Boolean {
        if (item instanceof P1ToggleItem) {
            return (item as P1ToggleItem).flip();
        }
        if (item instanceof ThemedToggleItem) {
            return (item as ThemedToggleItem).flip();
        }
        if (item instanceof StateMenuItem) {
            return (item as StateMenuItem).flip();
        }
        return (item as WatchUi.ToggleMenuItem).isEnabled();
    }
}

class ThemedToggleItem extends ThemedMenuItem {
    var _on as Lang.Boolean;
    var _subOn as Lang.String;
    var _subOff as Lang.String;

    function initialize(label as Lang.String, subOn as Lang.String, subOff as Lang.String,
                        on as Lang.Boolean, id as Lang.Object) {
        ThemedMenuItem.initialize(label, on ? subOn : subOff, id);
        _on = on;
        _subOn = subOn;
        _subOff = subOff;
    }

    function flip() as Lang.Boolean {
        _on = !_on;
        _sub = _on ? _subOn : _subOff;
        invalidate();
        WatchUi.requestUpdate();
        return _on;
    }
}

//! Native on/off row: the sublabel states the current value ("One verse per press" /
//! "One line per press"), so no green system switch is needed.
class StateMenuItem extends WatchUi.MenuItem {
    var _on as Lang.Boolean;
    var _subOn as Lang.String;
    var _subOff as Lang.String;

    function initialize(label as Lang.String, subOn as Lang.String, subOff as Lang.String,
                        on as Lang.Boolean, id as Lang.Object) {
        MenuItem.initialize(label, on ? subOn : subOff, id, null);
        _on = on;
        _subOn = subOn;
        _subOff = subOff;
    }

    function flip() as Lang.Boolean {
        _on = !_on;
        setSubLabel(_on ? _subOn : _subOff);
        WatchUi.requestUpdate();
        return _on;
    }
}

//! Per-device Menu2 background (monkey.jungle LIGHT_MENU_DEVICES): vivoactive5, venu3 and
//! venusq2 draw Menu2 lists on a white panel, so those builds use the dark CustomMenu.
(:darkmenu)
module MenuStyle {
    const DARK_NATIVE = true;
}

(:lightmenu)
module MenuStyle {
    const DARK_NATIVE = false;
}
