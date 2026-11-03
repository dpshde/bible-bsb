using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Dylan 2:56 PM: every menu follows Prime's P1 theme and still looks and acts like a native
//! Garmin Menu2. Menu2's own theming (`:theme`, API 4.1.8+) only offers fixed system accents
//! (MENU_THEME_BLUE … GREEN_YELLOW; ORANGE is the nearest to gold), so it can't carry P1's
//! cream / dark brown / muted gold or the app's Light theme. Menus are therefore a
//! WatchUi.CustomMenu (system scrolling, focus, wrap-around, BACK and Menu2InputDelegate) whose
//! rows are laid out like a native Menu2 row: title centered over a rule, label left-aligned in
//! a built-in font with the sublabel under it, and a focus bar at the left. Only colors differ,
//! all from Palette (BrandColors). POKE: MENU_P1 in UiMenu switches back to native Menu2.
class P1Menu extends WatchUi.CustomMenu {
    var _title as Lang.String;

    function initialize(title as Lang.String) {
        var h = MeasureDc.screenH();
        // POKE: P1_ROW_H — Menu2-like rows: title band, then the focused row in the middle of the
        // screen with one row above / below (Enduro 3 native shows the same).
        var row = (h * 0.27).toNumber();
        // The foreground mask paints the system's left focus gutter in the theme background
        // (fr265 draws a teal focus band and slanted cyan mark there: off-palette).
        CustomMenu.initialize(row, Palette.BG, {:focusItemHeight => row, :titleItemHeight => (h * 0.24).toNumber(),
            :foreground => new MenuFocusMask(row)});
        _title = title;
    }

    function drawTitle(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        var f = Graphics.FONT_TINY;
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h - dc.getFontHeight(f) - 8, f, _title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Palette.DIVIDER, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(w / 5, h - 3, w - w / 5, h - 3);
    }
}

class P1MenuItem extends WatchUi.CustomMenuItem {
    var _label as Lang.String;
    var _sub as Lang.String or Null;

    function initialize(label as Lang.String, sub as Lang.String or Null, id as Lang.Object) {
        CustomMenuItem.initialize(id, {});
        _label = label;
        _sub = sub;
    }

    //! Same names as MenuItem, so callers don't care which kind of menu they have.
    function setSubLabel(s as Lang.String or Lang.ResourceId or Null) as Void {
        _sub = s instanceof Lang.String || s == null ? s as Lang.String or Null : WatchUi.loadResource(s as Lang.ResourceId) as Lang.String;
        WatchUi.requestUpdate();
    }

    function setLabel(s as Lang.String or Lang.ResourceId) as Void {
        _label = s instanceof Lang.String ? s as Lang.String : WatchUi.loadResource(s as Lang.ResourceId) as Lang.String;
        WatchUi.requestUpdate();
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var focused = isFocused();
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear(); // over any system focus band (fr265: teal gradient)
        // POKE: P1_ROW_INSET — text starts where Menu2 starts it, just right of its focus bar.
        var x = (MeasureDc.screenW() * 0.06).toNumber();
        var room = w - x - (MeasureDc.screenW() * 0.04).toNumber();
        var lf = Graphics.FONT_SMALL;
        // Dylan 2026-11-03: sublabels in the light face (Faces.light: Enduro 3's built-in
        // RobotoCondensed-Regular; the regular system font elsewhere). Labels and titles stay bold.
        var sf = Faces.light(Graphics.FONT_TINY);
        var rows = [_label] as Lang.Array;
        if (dc.getTextWidthInPixels(_label, lf) > room) {
            lf = Graphics.FONT_TINY;
            if (dc.getTextWidthInPixels(_label, lf) > room) {
                // Long labels (section headings) wrap to two rows when there's no sublabel, like
                // Menu2 on newer devices; otherwise they end in "…".
                rows = _sub == null ? RoundLayout.wrapRows(dc, _label, lf, room, 2) : [fit(dc, _label, lf, room)];
            }
        }
        var lh = dc.getFontHeight(lf);
        var sh = _sub != null ? dc.getFontHeight(sf) : 0;
        var total = lh * rows.size() + sh;
        var y = (h - total) / 2;
        if (focused) {
            UiMenu.lastFocusId = getId();
            dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 9, y + 2, 4, total - 4);
        }
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < rows.size(); i++) {
            dc.drawText(x, y + lh * i, lf, rows[i] as Lang.String, Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (_sub != null) {
            dc.setColor(focused ? Palette.GOLD : Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y + lh * rows.size(), sf, fit(dc, _sub as Lang.String, sf, room), Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    function fit(dc as Graphics.Dc, s as Lang.String, f as Graphics.FontType, room as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(s, f) <= room) {
            return s;
        }
        var n = s.length();
        while (n > 1 && dc.getTextWidthInPixels(s.substring(0, n) + "…", f) > room) {
            n--;
        }
        return s.substring(0, n) + "…";
    }
}

//! On/off row whose sublabel names the current state (no system switch: it is drawn green).
class P1ToggleItem extends P1MenuItem {
    var _on as Lang.Boolean;
    var _subOn as Lang.String;
    var _subOff as Lang.String;

    function initialize(label as Lang.String, subOn as Lang.String, subOff as Lang.String,
                        on as Lang.Boolean, id as Lang.Object) {
        P1MenuItem.initialize(label, on ? subOn : subOff, id);
        _on = on;
        _subOn = subOn;
        _subOff = subOff;
    }

    function flip() as Lang.Boolean {
        _on = !_on;
        setSubLabel(_on ? _subOn : _subOff);
        return _on;
    }
}
