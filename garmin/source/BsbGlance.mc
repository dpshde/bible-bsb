using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

//! Glance: last-read ref + its words, else the offline verse of the day.
//! Native glance layout (5:50 PM, Dylan): no icon, box or border drawn by the app; the verse
//! is only ever shortened at a word boundary with an ellipsis.
(:glance)
class BsbGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }


    //! Native glance pattern (Weather, Steps): left-aligned, vertically centered in the
    //! glance DC, full DC width (the system draws the app icon outside this DC where a device
    //! shows one). Title = reference in gold; under it 1-2 light-gray verse rows ending "…".
    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var tf = Graphics.FONT_GLANCE;
        var bf = Graphics.FONT_GLANCE;
        var th = Graphics.getFontAscent(tf) + 2; // native glances set rows by ascent, not full font height
        var bh = Graphics.getFontAscent(bf) + 2;
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
        if (dc.getTextWidthInPixels(head, tf) > w) {
            head = shortRef(dc, head, tf, w);
        }
        // POKE: GLANCE_ROWS — verse rows under the title (1-2, as many as the DC holds).
        var rowsFit = (h - th) / bh;
        if (rowsFit > 2) {
            rowsFit = 2;
        }
        if (rowsFit < 1) {
            rowsFit = 1;
        }
        var rows = body.length() > 0 ? wrap(dc, body, bf, w, rowsFit) : [] as Lang.Array;
        var total = th + bh * rows.size();
        var y = (h - total) / 2 - (dc.getFontHeight(tf) - Graphics.getFontAscent(tf)) / 2;
        var ds = System.getDeviceSettings();
        var amoled = (ds has :requiresBurnInProtection) && ds.requiresBurnInProtection;
        dc.setColor(amoled ? 0xC89D54 : 0xFFAA55, Graphics.COLOR_TRANSPARENT); // gold; MIP nearest
        dc.drawText(0, y, tf, head, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var r;
        for (r = 0; r < rows.size(); r++) {
            dc.drawText(0, y + th + bh * r, bf, rows[r] as Lang.String, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    //! Last resort when "Book c:v" is wider than the DC: shorten the book word (logged).
    function shortRef(dc as Graphics.Dc, head as Lang.String, f as Graphics.FontDefinition,
                      w as Lang.Number) as Lang.String {
        var k = lastSpace(head);
        if (k <= 0) {
            return head;
        }
        var book = head.substring(0, k);
        var cv = head.substring(k, head.length());
        var n = book.length() - 1;
        while (n > 1 && dc.getTextWidthInPixels(book.substring(0, n) + "." + cv, f) > w) {
            n--;
        }
        System.println("NOTE glance ref shortened: " + head);
        return book.substring(0, n) + "." + cv;
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
