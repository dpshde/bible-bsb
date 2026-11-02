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
        CustomMenu.initialize((h * 0.18).toNumber(), Palette.BG, {
            :focusItemHeight => (h * 0.26).toNumber(),
            :titleItemHeight => (h * 0.22).toNumber()
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
        var fh = dc.getFontHeight(f);
        var sub = _sub;
        var sf = Graphics.FONT_XTINY;
        var sh = sub != null ? dc.getFontHeight(sf) : 0;
        var y = (h - fh - sh) / 2;
        var label = RoundLayout.ellipsize(dc, _label, f, w - 24);
        if (focused) {
            dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT); // no cards/pills
        } else {
            dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(w / 2, y, f, label, Graphics.TEXT_JUSTIFY_CENTER);
        if (sub != null) {
            dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y + fh + 1, sf, RoundLayout.ellipsize(dc, sub as Lang.String, sf, w - 24),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
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
        var room = focused ? (w * 0.80).toNumber() : (w * 0.72).toNumber();
        var full = _label + _suffix;
        var fonts = focused ? [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]
                            : [Graphics.FONT_TINY, Graphics.FONT_XTINY];
        var out = null;
        var k;
        for (k = 0; k < fonts.size() && out == null; k++) {
            var f = fonts[k] as Graphics.FontDefinition;
            if (dc.getTextWidthInPixels(full, f) <= room) {
                out = [f, [full]];
            }
        }
        var wrapFonts = focused ? [Graphics.FONT_TINY, Graphics.FONT_XTINY] : [Graphics.FONT_XTINY];
        for (k = 0; k < wrapFonts.size() && out == null; k++) {
            var f2 = wrapFonts[k] as Graphics.FontDefinition;
            var parts = RoundLayout.pyramidSplit(dc, full, f2, (room * 0.86).toNumber(), room);
            if (parts != null) {
                out = [f2, parts];
            } else if (focused && f2 == Graphics.FONT_XTINY) {
                // Focused item is taller: a third pyramid row before any truncation.
                var three = RoundLayout.wrapThree(dc, full, f2, (room * 0.72).toNumber(),
                                                  (room * 0.88).toNumber(), room);
                if (three != null) {
                    out = [f2, three];
                }
            }
        }
        if (out == null) {
            // Last resort: shorten the TITLE, keep the verse span whole on row 2.
            var f3 = Graphics.FONT_XTINY;
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
            dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_BG);
            dc.fillRoundedRectangle((w - tw) / 2, y - 1, tw, total + 2, 6);
            dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
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
    function isNative() as Lang.Boolean {
        return WatchUi has :MENU_THEME_ORANGE;
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
            return new WatchUi.ToggleMenuItem(label, {:enabled => subOn, :disabled => subOff}, id, on, null);
        }
        return new ThemedToggleItem(label, subOn, subOff, on, id);
    }

    //! State after the user selected a toggle item (native flips it itself).
    function toggledState(item) as Lang.Boolean {
        if (item instanceof ThemedToggleItem) {
            return (item as ThemedToggleItem).flip();
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
