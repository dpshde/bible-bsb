using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Go to verse by BSB section heading (Dylan 3:01 / 3:09 PM): "The Creation (1–25)".
//! Each row = title wrapped pyramid-style over <= 2 lines + the WHOLE verse range; if the
//! title is still too long only the title is shortened, never the range. Rows have their own
//! height, never overlap, and only rows that fit entirely inside the circle are drawn
//! (no half rows at the edges). Flat text list, no boxes. Last row "Verse…" = direct picking.
class GotoSectionsView extends WatchUi.View {
    var reader as ReaderView;
    var items as Lang.Array;    // [title, suffix, firstVerse]; firstVerse -1 = "Verse…"
    var focus as Lang.Number = 0;
    var count as Lang.Number;
    var _rows as Lang.Array or Null = null; // per item: [font, [lines], height, maxLineW]
    var _rects as Lang.Array = [] as Lang.Array; // drawn: [idx, y, h]
    var _top as Lang.Number = 0;
    var _bottom as Lang.Number = 0;
    const GAP = 4;
    var _fh as Lang.Number = 0;
    var _font as Graphics.FontDefinition = Graphics.FONT_TINY;
    var _shortened as Lang.Boolean = false;

    function initialize(r as ReaderView, its as Lang.Array, n as Lang.Number) {
        View.initialize();
        reader = r;
        items = its;
        count = n;
    }

    function layout(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        _top = RoundLayout.edgeMargin(w, h) + dc.getFontHeight(Graphics.FONT_TINY) + 6;
        _bottom = h - RoundLayout.edgeMargin(w, h);
        // POKE: GOTO_WRAP_ROOM — row text width (rows that don't fit their chord aren't drawn).
        var room = (w * 0.80).toNumber();
        // One font per list: TINY when every row fits in <= 2 lines unshortened, else XTINY.
        var fonts = [Graphics.FONT_TINY, Graphics.FONT_XTINY];
        var k;
        for (k = 0; k < fonts.size(); k++) {
            _font = fonts[k] as Graphics.FontDefinition;
            _fh = dc.getFontHeight(_font);
            _shortened = false;
            var rows = [] as Lang.Array;
            var i;
            for (i = 0; i < items.size(); i++) {
                var it = items[i] as Lang.Array;
                rows.add(fit(dc, it[0] as Lang.String, it[1] as Lang.String, room));
            }
            _rows = rows;
            if (!_shortened) {
                return;
            }
        }
    }

    //! One font for the whole list (rows look alike). One line if it fits; else pyramid
    //! 2 lines (line 1 <= line 2) with the range whole on line 2; else only the title part of
    //! line 2 is ellipsized, never the range.
    function fit(dc as Graphics.Dc, title as Lang.String, suffix as Lang.String, room as Lang.Number) as Lang.Array {
        var f = _font;
        var full = title + suffix;
        if (dc.getTextWidthInPixels(full, f) <= room) {
            return pack(dc, f, [full]);
        }
        var parts = RoundLayout.pyramidSplit(dc, full, f, (room * 0.86).toNumber(), room);
        if (parts != null && suffix.length() > 0
            && (parts[1] as Lang.String).find(suffix.substring(1, suffix.length())) != null) {
            return pack(dc, f, parts);
        }
        _shortened = true;
        var sw = dc.getTextWidthInPixels(suffix, f);
        var p = RoundLayout.pyramidSplitEllipsize(dc, title, f, (room * 0.86).toNumber(), room - sw);
        return pack(dc, f, [p[0], (p[1] as Lang.String) + suffix]);
    }

    function pack(dc as Graphics.Dc, f as Graphics.FontDefinition, lines as Lang.Array) as Lang.Array {
        var fh = dc.getFontHeight(f);
        var ws = [] as Lang.Array;
        var i;
        for (i = 0; i < lines.size(); i++) {
            ws.add(dc.getTextWidthInPixels(lines[i] as Lang.String, f));
        }
        return [f, lines, fh + (lines.size() - 1) * (fh - 3) + 6, ws];
    }

    //! A row is drawn only if it sits inside the window and EACH line fits the chord at
    //! that line's own top and bottom (no clipped glyphs, no half rows).
    function fits(y as Lang.Number, r as Lang.Array, w as Lang.Number, h as Lang.Number) as Lang.Boolean {
        var rh = r[2] as Lang.Number;
        if (y < _top || y + rh > _bottom) {
            return false;
        }
        var ws = r[3] as Lang.Array;
        var fh = _fh;
        var i;
        for (i = 0; i < ws.size(); i++) {
            var ly = y + 3 + i * (fh - 3);
            var need = (ws[i] as Lang.Number) + 8;
            if (RoundLayout.chordWidth(ly, w, h) < need || RoundLayout.chordWidth(ly + fh, w, h) < need) {
                return false;
            }
        }
        return true;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (_rows == null) {
            layout(dc);
        }
        var rows = _rows as Lang.Array;
        Palette.applyBackground(dc);
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        RoundLayout.drawCenteredInChord(dc, RoundLayout.edgeMargin(w, h), "Go to verse", Graphics.FONT_TINY);
        _rects = [] as Lang.Array;
        // Focused row centered in the window; neighbors stack outward until one won't fit.
        var fr = rows[focus] as Lang.Array;
        var fy = (_top + _bottom) / 2 - (fr[2] as Lang.Number) / 2;
        // Near the top of the list: start at the window top instead of leaving it empty.
        var above = 0;
        var j;
        for (j = 0; j < focus; j++) {
            above += ((rows[j] as Lang.Array)[2] as Lang.Number) + GAP;
        }
        if (fy - above > _top + 2) {
            fy = _top + 2 + above;
        }
        if (fy < _top) {
            fy = _top;
        }
        // The focused row itself must fit its chords: slide toward the middle until it does.
        var mid = (_top + _bottom) / 2 - (fr[2] as Lang.Number) / 2;
        while (fy < mid && !fits(fy, fr, w, h)) {
            fy += 2;
        }
        drawRow(dc, focus, fy, true, w);
        var y = fy;
        var i = focus - 1;
        while (i >= 0) {
            var r = rows[i] as Lang.Array;
            var rh = r[2] as Lang.Number;
            y -= rh + GAP;
            if (!fits(y, r, w, h)) {
                break;
            }
            drawRow(dc, i, y, false, w);
            i--;
        }
        var moreUp = i >= 0;
        y = fy + (fr[2] as Lang.Number) + GAP;
        i = focus + 1;
        while (i < rows.size()) {
            var r2 = rows[i] as Lang.Array;
            var rh2 = r2[2] as Lang.Number;
            if (!fits(y, r2, w, h)) {
                break;
            }
            drawRow(dc, i, y, false, w);
            y += rh2 + GAP;
            i++;
        }
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        if (moreUp) {
            dc.fillPolygon([[w / 2 - 5, _top - 1], [w / 2 + 5, _top - 1], [w / 2, _top - 5]]);
        }
        if (i < rows.size()) {
            dc.fillPolygon([[w / 2 - 5, _bottom], [w / 2 + 5, _bottom], [w / 2, _bottom + 4]]);
        }
    }

    function drawRow(dc as Graphics.Dc, idx as Lang.Number, y as Lang.Number, focused as Lang.Boolean, w as Lang.Number) as Void {
        var r = (_rows as Lang.Array)[idx] as Lang.Array;
        var f = r[0] as Graphics.FontDefinition;
        var lines = r[1] as Lang.Array;
        var rh = r[2] as Lang.Number;
        var fh = dc.getFontHeight(f);
        // Flat list (Dylan 3:11 PM): text only — focused row gold, the rest dimmed.
        dc.setColor(focused ? Palette.GOLD : Palette.DIM_VERSE, Graphics.COLOR_TRANSPARENT);
        var i;
        for (i = 0; i < lines.size(); i++) {
            Perf.texts++;
            dc.drawText(w / 2, y + 3 + i * (fh - 3), f, lines[i] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
        _rects.add([idx, y, rh]);
    }

    function indexAtY(y as Lang.Number) as Lang.Number {
        var i;
        for (i = 0; i < _rects.size(); i++) {
            var rc = _rects[i] as Lang.Array;
            if (y >= (rc[1] as Lang.Number) && y < (rc[1] as Lang.Number) + (rc[2] as Lang.Number)) {
                return rc[0] as Lang.Number;
            }
        }
        return -1;
    }

    function activate() as Void {
        var v = (items[focus] as Lang.Array)[2] as Lang.Number;
        if (v < 0) {
            // POKE: GOTO_VERSE_FALLBACK — direct verse picking (flat or range pages).
            ReaderMenu2.openVerseList(reader, count, 1);
            return;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        reader.jumpToVerse(v);
    }
}

class GotoSectionsDelegate extends WatchUi.BehaviorDelegate {
    var _v as GotoSectionsView;

    function initialize(v as GotoSectionsView) {
        BehaviorDelegate.initialize();
        _v = v;
    }

    function onNextPage() as Lang.Boolean {
        _v.focus = (_v.focus + 1) % _v.items.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        var n = _v.items.size();
        _v.focus = (_v.focus + n - 1) % n;
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Lang.Boolean {
        return false; // TAP FIX: Enter via onKey, taps via onTap
    }

    function onKey(evt as WatchUi.KeyEvent) as Lang.Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            _v.activate();
            return true;
        }
        return false;
    }

    function onTap(evt as WatchUi.ClickEvent) as Lang.Boolean {
        var i = _v.indexAtY(evt.getCoordinates()[1]);
        if (i >= 0) {
            _v.focus = i;
            Feedback.tick();
            _v.activate();
        }
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
