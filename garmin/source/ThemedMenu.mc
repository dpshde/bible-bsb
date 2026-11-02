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
        var sub = focused ? _sub : null;
        var sf = Graphics.FONT_XTINY;
        var sh = sub != null ? dc.getFontHeight(sf) : 0;
        var y = (h - fh - sh) / 2;
        var label = RoundLayout.ellipsize(dc, _label, f, w - 24);
        if (focused) {
            var tw = dc.getTextWidthInPixels(label, f) + 20;
            if (tw > w - 8) {
                tw = w - 8;
            }
            dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_BG);
            dc.fillRoundedRectangle((w - tw) / 2, y - 1, tw, fh + 2, 6);
            dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
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
