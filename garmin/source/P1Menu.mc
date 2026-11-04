using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

//! Dylan 2:56 PM: every menu follows Prime's P1 theme and still looks and acts like a native
//! Garmin Menu2. Menu2's own theming (`:theme`, API 4.1.8+) only offers fixed system accents
//! (MENU_THEME_BLUE … GREEN_YELLOW; ORANGE is the nearest to gold), so it can't carry P1's
//! cream / dark brown / muted gold or the app's Light theme. Menus are therefore a
//! WatchUi.CustomMenu (system scrolling, focus, wrap-around, BACK and Menu2InputDelegate) whose
//! rows are laid out like a native Menu2 row: title centered over a rule, label left-aligned in
//! a built-in font with the sublabel under it, and a focus bar at the left. Only colors differ,
//! all from Palette (BrandColors). POKE: MENU_P1 in UiMenu switches back to native Menu2.
//! Sizes (Dylan 2026-11-03, "zoomed out"): Zoom.mc.
class P1Menu extends WatchUi.CustomMenu {
    var _title as Lang.String;

    function initialize(title as Lang.String) {
        var h = MeasureDc.screenH();
        var row = Zoom.menuRowH();
        // The foreground mask paints the system's left focus gutter in the theme background
        // (fr265 draws a teal focus band and slanted cyan mark there: off-palette).
        CustomMenu.initialize(row, Palette.BG, {:focusItemHeight => row, :titleItemHeight => (h * Zoom.MENU_TITLE_FRAC).toNumber(),
            :foreground => new MenuFocusMask(row)});
        _title = title;
    }

    function drawTitle(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        var f = Zoom.MENU_TITLE_FONT;
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        Faces.drawHead(dc, w / 2, h - dc.getFontHeight(f) - 5, f, _title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Palette.DIVIDER, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(w / 5, h - 2, w - w / 5, h - 2);
        Perf.navPaint("menu " + _title);
    }
}

class P1MenuItem extends WatchUi.CustomMenuItem {
    var _label as Lang.String;
    var _sub as Lang.String or Null;
    // PERF (lag pass): the fitted label rows / sublabel are measured once per text, not every frame
    // (Enduro 3's light face is a vector font: each width measure is costly, and "…" fitting
    // measured up to ~20 times per row per frame).
    var _lay as Lang.Array or Null = null; // [labelFont, rows, fittedSub]

    function initialize(label as Lang.String, sub as Lang.String or Null, id as Lang.Object) {
        CustomMenuItem.initialize(id, {});
        _label = label;
        _sub = sub;
    }

    //! Same names as MenuItem, so callers don't care which kind of menu they have.
    function setSubLabel(s as Lang.String or Lang.ResourceId or Null) as Void {
        _sub = s instanceof Lang.String || s == null ? s as Lang.String or Null : WatchUi.loadResource(s as Lang.ResourceId) as Lang.String;
        _lay = null;
        UiMenu.rowRev++;
        WatchUi.requestUpdate();
    }

    function setLabel(s as Lang.String or Lang.ResourceId) as Void {
        _label = s instanceof Lang.String ? s as Lang.String : WatchUi.loadResource(s as Lang.ResourceId) as Lang.String;
        _lay = null;
        UiMenu.rowRev++;
        WatchUi.requestUpdate();
    }

    function layout(dc as Graphics.Dc, room as Lang.Number) as Lang.Array {
        var lf = Zoom.MENU_LABEL_FONT;
        var sf = Faces.light(Zoom.MENU_SUB_FONT);
        var rows = [_label] as Lang.Array;
        if (dc.getTextWidthInPixels(_label, lf) > room) {
            // Long labels (section headings) wrap to two rows when there's no sublabel, like
            // Menu2 on newer devices; otherwise they end in "…".
            rows = _sub == null ? RoundLayout.wrapRows(dc, _label, lf, room, 2) : [fit(dc, _label, lf, room)];
        }
        // [4] label overflow px (one fitted row only), [5] sublabel overflow px, [6] room
        var lo = rows.size() == 1 ? dc.getTextWidthInPixels(_label, lf) - room : 0;
        var so = _sub != null ? dc.getTextWidthInPixels(_sub as Lang.String, sf) - room : 0;
        return [lf, rows, _sub != null ? fit(dc, _sub as Lang.String, sf, room) : null, sf, lo, so, room];
    }

    // 0.9.8 marquee (FastMenu drives it): mq = px scrolled; mqOver = how far there is to go.
    var mq as Lang.Number = 0;
    var _mqGeo as Lang.Array or Null = null; // [textX, room, [[font, text, y, h, over, color]...]]

    function mqGeo() as Lang.Array or Null {
        return _mqGeo;
    }

    function mqOver() as Lang.Number {
        if (_lay == null) {
            return 0;
        }
        var lay = _lay as Lang.Array;
        var a = lay[4] as Lang.Number;
        var b = lay[5] as Lang.Number;
        return a > b ? a : b;
    }

    function draw(dc as Graphics.Dc) as Void {
        var t0 = Perf.now();
        var focused = isFocused();
        if (focused) {
            UiMenu.lastFocusId = getId();
        }
        paint(dc, focused);
        Perf.rowN++;
        Perf.rowMs += Perf.now() - t0;
    }

    //! The row in one state on an item-sized dc (CustomMenu's item dc, or FastMenu's bitmap).
    function paint(dc as Graphics.Dc, focused as Lang.Boolean) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear(); // over any system focus band (fr265: teal gradient)
        // POKE: P1_ROW_INSET — text starts where Menu2 starts it, just right of its focus bar.
        var x = (MeasureDc.screenW() * Zoom.MENU_INSET_FRAC).toNumber();
        if (_lay == null) {
            var room = w - x - (MeasureDc.screenW() * 0.04).toNumber();
            if (System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND) {
                var r2 = (MeasureDc.screenW() * Zoom.MENU_ROOM_FRAC).toNumber() - x;
                room = r2 < room ? r2 : room;
            }
            _lay = layout(dc, room);
        }
        var lay = _lay as Lang.Array;
        var lf = lay[0] as Graphics.FontType;
        var rows = lay[1] as Lang.Array;
        var sub = lay[2];
        var sf = lay[3] as Graphics.FontType;
        var lh = dc.getFontHeight(lf);
        // Rows sit tight: the label's descender space overlaps the sublabel's ascender space.
        var gap = Zoom.MENU_LINE_OVERLAP;
        var sh = sub != null ? dc.getFontHeight(sf) - gap : 0;
        var total = lh * rows.size() + sh;
        var y = (h - total) / 2;
        if (focused) {
            dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 7, y + 3, 3, total - 5);
        }
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < rows.size(); i++) {
            dc.drawText(x, y + lh * i, lf, rows[i] as Lang.String, Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (sub != null) {
            dc.setColor(focused ? Palette.GOLD : Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y + lh * rows.size() - gap, sf, sub as Lang.String, Graphics.TEXT_JUSTIFY_LEFT);
        }
        // 0.9.8e marquee geometry: the lines that overflow, for FastMenu's one-time text strips.
        var ml = [] as Lang.Array;
        if (rows.size() == 1 && (lay[4] as Lang.Number) > 0) {
            ml.add([lf, _label, y, lh, lay[4], Palette.TEXT]);
        }
        if (sub != null && (lay[5] as Lang.Number) > 0) {
            ml.add([sf, _sub, y + lh * rows.size() - gap, dc.getFontHeight(sf), lay[5], Palette.GOLD]);
        }
        _mqGeo = [x, lay[6], ml];
    }

    function fit(dc as Graphics.Dc, s as Lang.String, f as Graphics.FontType, room as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(s, f) <= room) {
            return s;
        }
        // Binary search on the cut (was one measure per dropped character).
        var lo = 1;
        var hi = s.length();
        while (lo < hi) {
            var mid = (lo + hi + 1) / 2;
            if (dc.getTextWidthInPixels(s.substring(0, mid) + "…", f) <= room) {
                lo = mid;
            } else {
                hi = mid - 1;
            }
        }
        return s.substring(0, lo) + "…";
    }
}

//! Bookmarks row: label = reference, sublabel = "Color · verse start" (Snippets), made the first
//! time the row is drawn so the list opens without loading every bookmarked chapter.
class BookmarkItem extends P1MenuItem {
    var _color as Lang.String or Null;
    var _pending as Lang.Boolean = true;

    function initialize(label as Lang.String, color as Lang.String or Null, id as Lang.Number) {
        P1MenuItem.initialize(label, color, id);
        _color = color;
    }

    static function join(color as Lang.String or Null, sn as Lang.String or Null) as Lang.String or Null {
        if (color == null) {
            return sn;
        }
        return sn == null ? color : (color as Lang.String) + " · " + sn;
    }

    function paint(dc as Graphics.Dc, focused as Lang.Boolean) as Void {
        if (_pending) {
            _pending = false;
            var id = getId() as Lang.Number;
            var sn = Snippets.of(id & 0xFFFFFF); // a merged row: its first verse's text + "…"
            if (sn != null && Bookmarks.isRange(id) && !(sn as Lang.String).substring((sn as Lang.String).length() - 1, null).equals("…")) {
                sn = (sn as Lang.String) + "…";
            }
            _sub = join(_color, sn);
            _lay = null;
        }
        P1MenuItem.paint(dc, focused);
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
