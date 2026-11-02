using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Glance: last-read ref + its first line, then the offline verse of the day.
(:glance)
class BsbGlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var f = Graphics.FONT_GLANCE;
        var fh = dc.getFontHeight(f);
        var ref = LastRead.ref();
        var line1;
        var line2;
        if (ref != null) {
            line1 = "BSB  " + ref;
            var t = LastRead.text();
            line2 = t != null ? t as Lang.String : "";
        } else {
            var i = Votd.index();
            line1 = "VOTD  " + Votd.REFS[i];
            line2 = Votd.TEXTS[i] as Lang.String;
        }
        var y = (h - 2 * fh) / 2;
        if (y < 0) {
            y = 0;
        }
        dc.setColor(0xFFAA55, Graphics.COLOR_TRANSPARENT); // gold (MIP-safe)
        dc.drawText(0, y, f, line1, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, y + fh, f, fit(dc, line2, f, w), Graphics.TEXT_JUSTIFY_LEFT);
    }

    function fit(dc as Graphics.Dc, s as Lang.String, f as Graphics.FontDefinition, maxW as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(s, f) <= maxW) {
            return s;
        }
        var t = s;
        while (t.length() > 1 && dc.getTextWidthInPixels(t + "..", f) > maxW) {
            t = t.substring(0, t.length() - 1);
        }
        return t + "..";
    }
}
