using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

//! POKE: MENU_THEME — native Menu2 is system-themed (always dark), so every app menu is a
//! CustomMenu drawn with Palette (follows Dark/Light). Same Menu2InputDelegate API.
class ThemedMenu extends WatchUi.CustomMenu {
    var _title as Lang.String;

    function initialize(title as Lang.String) {
        var h = System.getDeviceSettings().screenHeight;
        // POKE: MENU_ROW_H — 30% rows: only the rows above/below focus are on screen, both
        // where the circle is still wide, so no row runs into the bezel.
        CustomMenu.initialize((h * 0.30).toNumber(), Palette.BG, {
            :focusItemHeight => (h * 0.30).toNumber(),
            :titleItemHeight => (h * 0.22).toNumber(),
            :foreground => new MenuFocusMask((h * 0.30).toNumber())
        });
        _title = title;
    }

    function drawTitle(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        var f = Graphics.FONT_TINY;
        dc.drawText(w / 2, h - dc.getFontHeight(f) - 6, f, _title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Palette.DIVIDER_RULE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(w / 6, h - 2, w - w / 6, h - 2);
    }
}

class ThemedMenuItem extends WatchUi.CustomMenuItem {
    var _label as Lang.String;
    var _sub as Lang.String or Null;

    function initialize(label as Lang.String, sub as Lang.String or Null, id as Lang.Object) {
        CustomMenuItem.initialize(id, {});
        _label = label;
        _sub = sub;
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var focused = isFocused();
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        var f = focused ? Graphics.FONT_SMALL : Graphics.FONT_TINY;
        // POKE: MENU_ROW_ROOM — rows above/below focus sit where the circle is narrower; the
        // focused row also clears the system focus mark masked by MenuFocusMask.
        var room = focused ? (w * 0.74).toNumber() : (w * 0.66).toNumber();
        var rows = [_label] as Lang.Array;
        if (dc.getTextWidthInPixels(_label, f) > room) {
            // Wrap to two rows (one font for both, dropping to TINY on focus) before any "…".
            f = Graphics.FONT_TINY;
            if (dc.getTextWidthInPixels(_label, f) > room) {
                rows = RoundLayout.wrapRows(dc, _label, f, room, 2);
            }
        }
        var fh = dc.getFontHeight(f);
        var lh = fh - 3;
        var sf = Graphics.FONT_XTINY;
        var sh = dc.getFontHeight(sf);
        var slh = sh - 3;
        var subRows = _sub != null
            ? RoundLayout.wrapRows(dc, _sub as Lang.String, sf, room, rows.size() > 1 ? 1 : 2)
            : [] as Lang.Array;
        var th = fh + (rows.size() - 1) * lh;
        var stotal = subRows.size() > 0 ? sh + (subRows.size() - 1) * slh : 0;
        var y = (h - th - stotal) / 2;
        if (focused) {
            dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT); // no cards/pills
        } else {
            dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        }
        var i;
        for (i = 0; i < rows.size(); i++) {
            dc.drawText(w / 2, y + i * lh, f, rows[i] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        for (i = 0; i < subRows.size(); i++) {
            dc.drawText(w / 2, y + th + 1 + i * slh, sf, subRows[i] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
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
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Palette.BG, Palette.BG);
        // POKE: MENU_MASK_W — the system keeps a left gutter (~13% of the width) for its focus
        // mark and fills it black; paint it in the theme background over the full height so
        // Light mode has no dark strip.
        dc.fillRectangle(0, 0, (w * 0.13).toNumber() + 1, h);
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
        var room = focused ? (w * 0.74).toNumber() : (w * 0.62).toNumber();
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
        var w = dc.getWidth();
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
        if (focused) {
            var tw = 0;
            var i0;
            for (i0 = 0; i0 < rows.size(); i0++) {
                var rw = dc.getTextWidthInPixels(rows[i0] as Lang.String, f);
                tw = rw > tw ? rw : tw;
            }
            tw += 20;
            if (tw > w - 8) {
                tw = w - 8;
            }
            dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT); // gold text, no pill
        } else {
            dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        }
        var i;
        for (i = 0; i < rows.size(); i++) {
            dc.drawText(w / 2, y + i * lh, f, rows[i] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
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

    function isNative() as Lang.Boolean {
        return MENU_NATIVE && MenuStyle.DARK_NATIVE && (WatchUi has :MENU_THEME_ORANGE);
    }

    function create(title as Lang.String) {
        if (isNative()) {
            return new WatchUi.Menu2({:title => title, :theme => WatchUi.MENU_THEME_ORANGE});
        }
        return new ThemedMenu(title);
    }

    function item(label as Lang.String, sub as Lang.String or Null, id as Lang.Object) {
        if (isNative()) {
            return new WatchUi.MenuItem(label, sub, id, null);
        }
        return new ThemedMenuItem(label, sub, id);
    }

    //! On/off setting with a plain-language sublabel for each state.
    //! Native: ToggleMenuItem (system switch). Fallback: ThemedToggleItem (sublabel flips).
    function toggle(label as Lang.String, subOn as Lang.String, subOff as Lang.String,
                    on as Lang.Boolean, id as Lang.Object) {
        if (isNative()) {
            // Plain native item whose sublabel names the current state: no system switch
            // (the system draws it green on every target, and green is off-palette).
            return new StateMenuItem(label, subOn, subOff, on, id);
        }
        return new ThemedToggleItem(label, subOn, subOff, on, id);
    }

    //! State after the user selected a toggle item (native flips it itself).
    function toggledState(item) as Lang.Boolean {
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
