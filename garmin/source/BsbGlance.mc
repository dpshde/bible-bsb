using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

//! Glance: last-read ref + its words, else the offline verse of the day.
//! Every row is centered inside SAFE_FRAC of the glance width (round bezels clip the slot's
//! corners); the verse word-wraps over the rows that fit and is only ever shortened at a
//! word boundary with an ellipsis (edge pass: "Whatever you do, work ." fixed).
(:glance)
class BsbGlanceView extends WatchUi.GlanceView {
    // POKE: GLANCE_SAFE_FRAC — usable width share of the glance slot.
    const SAFE_FRAC = 0.82;

    function initialize() {
        GlanceView.initialize();
    }

    var _logged as Lang.Boolean = false;

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (!_logged) {
            _logged = true; // safe-area audit: the system places this DC right of the app icon
            System.println("GLANCE dc " + w + "x" + h);
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var f = Graphics.FONT_GLANCE;
        var fh = dc.getFontHeight(f);
        var ref = LastRead.ref();
        var head;
        var body;
        if (ref != null) {
            head = ref as Lang.String;
            var t = LastRead.text();
            body = t != null ? t as Lang.String : "";
        } else {
            var i = Votd.index();
            head = Votd.REFS[i] as Lang.String;
            body = Votd.TEXTS[i] as Lang.String;
        }
        var room = (w * SAFE_FRAC).toNumber();
        var maxRows = h / fh - 1;
        if (maxRows < 1) {
            maxRows = 1;
        }
        if (maxRows > 3) {
            maxRows = 3;
        }
        var rows = wrap(dc, body, f, room, maxRows);
        var total = fh * (1 + rows.size());
        var y = (h - total) / 2;
        if (y < 0) {
            y = 0;
        }
        dc.setColor(0xFFAA55, Graphics.COLOR_TRANSPARENT); // gold (MIP-safe)
        dc.drawText(w / 2, y, f, head, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var r;
        for (r = 0; r < rows.size(); r++) {
            dc.drawText(w / 2, y + fh * (r + 1), f, rows[r] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Greedy word wrap into <= maxRows rows of width <= room. If words remain, the last row
    //! drops whole words until "row…" fits (never cuts inside a word).
    function wrap(dc as Graphics.Dc, s as Lang.String, f as Graphics.FontDefinition,
                  room as Lang.Number, maxRows as Lang.Number) as Lang.Array {
        var words = [] as Lang.Array;
        var rest = s;
        while (rest.length() > 0) {
            var sp = rest.find(" ");
            if (sp == null) {
                words.add(rest);
                break;
            }
            if (sp > 0) {
                words.add(rest.substring(0, sp));
            }
            rest = rest.substring(sp + 1, rest.length());
        }
        var rows = [] as Lang.Array;
        var cur = "";
        var i = 0;
        while (i < words.size()) {
            var wd = words[i] as Lang.String;
            var cand = cur.length() == 0 ? wd : cur + " " + wd;
            if (dc.getTextWidthInPixels(cand, f) <= room || cur.length() == 0) {
                cur = cand;
                i++;
            } else {
                rows.add(cur);
                cur = "";
                if (rows.size() == maxRows) {
                    break;
                }
            }
        }
        if (cur.length() > 0 && rows.size() < maxRows) {
            rows.add(cur);
        }
        if (i < words.size() && rows.size() > 0) {
            // Truncated: last row ends at a word + ellipsis.
            var last = rows[rows.size() - 1] as Lang.String;
            while (dc.getTextWidthInPixels(last + "…", f) > room) {
                var cut = lastSpace(last);
                if (cut <= 0) {
                    break;
                }
                last = last.substring(0, cut);
            }
            rows[rows.size() - 1] = last + "…";
        }
        return rows;
    }

    function lastSpace(s as Lang.String) as Lang.Number {
        var k = s.length() - 1;
        while (k > 0) {
            if (s.substring(k, k + 1).equals(" ")) {
                return k;
            }
            k--;
        }
        return 0;
    }
}
