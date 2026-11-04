using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;

//! Center-band lens geometry + helpers for Enduro 3 / budget lines.
module RoundLayout {

    // POKE: READER_LAYOUT — LENS is the new default; RECT/CENTERED_CHORD kept for A/B.
    enum {
        READER_LAYOUT_RECT = 0,
        READER_LAYOUT_CENTERED_CHORD = 1,
        READER_LAYOUT_LENS = 2
    }
    const READER_LAYOUT = READER_LAYOUT_LENS;

    // Lens vertical fracs (round + square band).
    // POKE: tweak top/meta vs band vs preview split after Enduro reshoot.
    const LENS_META_BOTTOM_FRAC = 0.18;
    const LENS_BAND_TOP_FRAC = 0.20;
    // POKE: LENS_CHORD_INSET — px kept clear between band corners and the rim/progress arc.
    const LENS_CHORD_INSET = 7;
    // POKE: PROGRESS_ARC — ring thickness (px) and bottom gap (deg, 0 = full ring).
    const PROGRESS_ARC_PEN = 3;
    const PROGRESS_ARC_GAP_DEG = 0;
    const LENS_BAND_BOTTOM_FRAC = 0.80;
    const LENS_PREVIEW_TOP_FRAC = 0.82;

    // POKE: bottom arc shows verse counter; set false to prefer next-verse preview words.
    const LENS_PREVIEW_VERSE_COUNTER = true;

    const COLUMN_PIXEL_PAD = 6;
    const COLUMN_WIDTH_MIN_FRAC = 0.75; // lens band must be >= 0.75 D on 280 (Dylan)
    const CHORD_MARGIN_FRAC = 0.07;
    const EDGE_MARGIN_FRAC = 0.06;
    const DIVIDER_PAD_LINES = 1; // ~1 line air above/below continuation header
    const TOAST_MS = 1000;
    const MODE_BANNER_ONLY = true;
    // POKE: VERSE_GAP_FRAC — vertical gap between verses as a fraction of line height (0.4–0.5).
    const VERSE_GAP_FRAC = 0.45;
    // POKE: SHORT_VERSE_CHARS — system FONT_TINY bump when verse text length <= this.
    const SHORT_VERSE_CHARS = 40;

    // Legacy RECT constants (still used if READER_LAYOUT_RECT).
    const COLUMN_WIDTH_FRAC = 0.80;
    const COLUMN_BAND_TOP_FRAC = 0.22;
    const COLUMN_BAND_BOTTOM_FRAC = 0.86;

    function isRound() as Lang.Boolean {
        var shape = System.getDeviceSettings().screenShape;
        return shape == System.SCREEN_SHAPE_ROUND || shape == System.SCREEN_SHAPE_SEMI_ROUND;
    }

    function edgeMargin(width as Lang.Number, height as Lang.Number) as Lang.Number {
        var m = ((width < height ? width : height) * EDGE_MARGIN_FRAC).toNumber();
        if (m < 6) {
            m = 6;
        }
        return m;
    }

    function chordWidth(y as Lang.Number, width as Lang.Number, height as Lang.Number) as Lang.Number {
        var margin = edgeMargin(width, height);
        var maxW = width - 2 * margin;
        if (maxW < 1) {
            maxW = 1;
        }
        if (!isRound()) {
            return maxW;
        }
        var cy = height / 2.0;
        var r = (width < height ? width : height) / 2.0;
        var dy = y.toFloat() - cy;
        var inside = r * r - dy * dy;
        if (inside <= 0) {
            return 1;
        }
        var half = Math.sqrt(inside) - (r * CHORD_MARGIN_FRAC);
        if (half < 1.0) {
            half = 1.0;
        }
        var cw = (half * 2.0).toNumber();
        if (cw > maxW) {
            cw = maxW;
        }
        return cw < 1 ? 1 : cw;
    }

    function chordLeft(y as Lang.Number, width as Lang.Number, height as Lang.Number) as Lang.Number {
        return (width - chordWidth(y, width, height)) / 2;
    }

    //! Pure: W(y) = 2*sqrt(R^2 - (y-cy)^2) with pixel pad (no % margin).
    function rawChordWidth(y as Lang.Number, screenW as Lang.Number, screenH as Lang.Number) as Lang.Number {
        var r = (screenW < screenH ? screenW : screenH) / 2.0;
        var cy = screenH / 2.0;
        var dy = y.toFloat() - cy;
        var inside = r * r - dy * dy;
        if (inside <= 0) {
            return 1;
        }
        var half = Math.sqrt(inside) - COLUMN_PIXEL_PAD;
        if (half < 1.0) {
            half = 1.0;
        }
        return (half * 2.0).toNumber();
    }

    //! Pure lens column width for a band (round geometry). Floor at COLUMN_WIDTH_MIN_FRAC * D.
    function lensColumnWidth(screenW as Lang.Number, screenH as Lang.Number,
                             bandTop as Lang.Number, bandBottom as Lang.Number) as Lang.Number {
        var wTop = rawChordWidth(bandTop, screenW, screenH);
        var wBot = rawChordWidth(bandBottom, screenW, screenH);
        var colW = wTop < wBot ? wTop : wBot;
        var floorW = (screenW * COLUMN_WIDTH_MIN_FRAC).toNumber();
        if (colW < floorW) {
            colW = floorW;
        }
        return colW;
    }

    //! Center-band lens geometry. Returns:
    //! { :metaBottom, :bandTop, :bandBottom, :previewTop, :left, :width, :bandHeight }
    function lensBand(screenW as Lang.Number, screenH as Lang.Number) as Lang.Dictionary {
        return lensBandEx(screenW, screenH, isRound());
    }

    function lensBandEx(screenW as Lang.Number, screenH as Lang.Number,
                        treatAsRound as Lang.Boolean) as Lang.Dictionary {
        var metaBottom = (screenH * LENS_META_BOTTOM_FRAC).toNumber();
        var bandTop = (screenH * LENS_BAND_TOP_FRAC).toNumber();
        var bandBottom = (screenH * LENS_BAND_BOTTOM_FRAC).toNumber();
        var previewTop = (screenH * LENS_PREVIEW_TOP_FRAC).toNumber();
        if (bandBottom <= bandTop + 1) {
            bandBottom = bandTop + 1;
        }

        var colW;
        var left;
        if (!treatAsRound) {
            var m = edgeMargin(screenW, screenH);
            colW = screenW - 2 * m;
            left = m;
        } else {
            colW = lensColumnWidth(screenW, screenH, bandTop, bandBottom) - 2 * LENS_CHORD_INSET;
            var floorW = (screenW * COLUMN_WIDTH_MIN_FRAC).toNumber();
            if (colW < floorW) {
                colW = floorW; // Dylan: never below 0.75 D
            }
            left = (screenW - colW) / 2;
        }
        return {
            :metaBottom => metaBottom,
            :bandTop => bandTop,
            :bandBottom => bandBottom,
            :previewTop => previewTop,
            :left => left,
            :width => colW,
            :bandHeight => bandBottom - bandTop
        };
    }

    //! True if [y, y+h) lies fully inside the reading band.
    function isInsideBand(y as Lang.Number, h as Lang.Number, bandTop as Lang.Number,
                          bandBottom as Lang.Number) as Lang.Boolean {
        return y >= bandTop && (y + h) <= bandBottom;
    }

    function inscribedColumnWidth(screenW as Lang.Number, screenH as Lang.Number,
                                  contentTop as Lang.Number, contentBottom as Lang.Number) as Lang.Number {
        var colW = lensColumnWidth(screenW, screenH, contentTop, contentBottom);
        var maxW = (screenW * COLUMN_WIDTH_FRAC).toNumber();
        if (colW > maxW) {
            colW = maxW;
        }
        return colW;
    }

    function columnRect(width as Lang.Number, height as Lang.Number,
                        contentTop as Lang.Number, contentBottom as Lang.Number) as Lang.Dictionary {
        if (READER_LAYOUT == READER_LAYOUT_LENS) {
            var lens = lensBand(width, height);
            return {
                :left => lens[:left],
                :width => lens[:width],
                :top => lens[:bandTop],
                :bottom => lens[:bandBottom]
            };
        }
        var top = contentTop;
        var bottom = contentBottom;
        if (bottom <= top + 1) {
            bottom = top + 1;
        }
        if (!isRound()) {
            var m = edgeMargin(width, height);
            return { :left => m, :width => width - 2 * m, :top => top, :bottom => bottom };
        }
        var colW = inscribedColumnWidth(width, height, top, bottom);
        return { :left => (width - colW) / 2, :width => colW, :top => top, :bottom => bottom };
    }

    function maxCenteredColumnWidth(screenW as Lang.Number, screenH as Lang.Number,
                                     contentTop as Lang.Number, contentBottom as Lang.Number,
                                     chordMarginFrac as Lang.Float) as Lang.Number {
        return inscribedColumnWidth(screenW, screenH, contentTop, contentBottom);
    }

    //! Two-line split: prefer line1 <= line2 (pyramid); if no such split fits both
    //! widths, take any fitting split with the smallest overhang of line1. Null if none fits.
    function pyramidSplit(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontType,
                          w1 as Lang.Number, w2 as Lang.Number) as Lang.Array or Null {
        var words = ContentLoader.splitWords(text);
        var best = null;
        var bestScore = 0;
        var k;
        for (k = 1; k < words.size(); k++) {
            var a = "";
            var b = "";
            var i;
            for (i = 0; i < words.size(); i++) {
                if (i < k) {
                    a = a.length() == 0 ? words[i] as Lang.String : a + " " + words[i];
                } else {
                    b = b.length() == 0 ? words[i] as Lang.String : b + " " + words[i];
                }
            }
            var wa = dc.getTextWidthInPixels(a, font);
            var wb = dc.getTextWidthInPixels(b, font);
            if (wa <= w1 && wb <= w2) {
                // pyramid splits score by line1 width; inverted ones rank below all pyramids.
                var score = wa <= wb ? 100000 + wa : 50000 - (wa - wb);
                if (best == null || score > bestScore) {
                    best = [a, b];
                    bestScore = score;
                }
            }
        }
        return best;
    }

    //! Last-resort two lines (nothing fits whole): line 1 = a word prefix inside w1, line 2 =
    //! the following words cut at a WORD boundary + "…" inside w2. Picks the split that
    //! shows the most words, pyramid (line 1 <= line 2) on ties. Ellipsis only on line 2.
    function pyramidSplitEllipsize(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontType,
                                   w1 as Lang.Number, w2 as Lang.Number) as Lang.Array {
        var whole = pyramidSplit(dc, text, font, w1, w2);
        if (whole != null) {
            return whole as Lang.Array;
        }
        var words = ContentLoader.splitWords(text);
        var best = null;
        var bestScore = -1;
        var a = "";
        var k;
        for (k = 1; k < words.size(); k++) {
            a = a.length() == 0 ? words[k - 1] as Lang.String : a + " " + words[k - 1];
            var wa = dc.getTextWidthInPixels(a, font);
            if (wa > w1) {
                break;
            }
            var m = words.size();
            var b = "";
            while (m > k) {
                b = "";
                var i;
                for (i = k; i < m; i++) {
                    b = b.length() == 0 ? words[i] as Lang.String : b + " " + words[i];
                }
                if (dc.getTextWidthInPixels(b + "…", font) <= w2) {
                    break;
                }
                m--;
            }
            if (m == k) {
                b = ellipsize(dc, words[k] as Lang.String, font, w2); // one over-long word
                m = k + 1;
            } else {
                b = b + "…";
            }
            var wb = dc.getTextWidthInPixels(b, font);
            var score = m * 10000 + (wa <= wb ? 5000 : 0) + wa;
            if (score > bestScore) {
                best = [a, b];
                bestScore = score;
            }
        }
        if (best == null) {
            return ["", ellipsize(dc, text, font, w2)];
        }
        return best as Lang.Array;
    }

    //! Three rows, row 1 <= row 2 (pyramid), each inside its chord. Null if no fit.
    function wrapThree(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontType,
                       c1 as Lang.Number, c2 as Lang.Number, c3 as Lang.Number) as Lang.Array or Null {
        var words = ContentLoader.splitWords(text);
        var best = null;
        var bestScore = 0;
        var k;
        var a = "";
        for (k = 1; k < words.size() - 1; k++) {
            a = a.length() == 0 ? words[k - 1] as Lang.String : a + " " + words[k - 1];
            var wa = dc.getTextWidthInPixels(a, font);
            if (wa > c1) {
                break;
            }
            var rest = "";
            var i;
            for (i = k; i < words.size(); i++) {
                rest = rest.length() == 0 ? words[i] as Lang.String : rest + " " + words[i];
            }
            var two = pyramidSplit(dc, rest, font, c2, c3);
            if (two == null) {
                continue;
            }
            var wb = dc.getTextWidthInPixels(two[0] as Lang.String, font);
            var score = wa <= wb ? 100000 + wa : 50000 - (wa - wb);
            if (best == null || score > bestScore) {
                best = [a, two[0], two[1]];
                bestScore = score;
            }
        }
        return best;
    }

    function ellipsize(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontType,
                       maxW as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(text, font) <= maxW) {
            return text;
        }
        // Prefer whole words: drop trailing words while at least one word remains.
        var s = text;
        var sp = lastSpaceAt(s);
        while (sp > 0) {
            s = s.substring(0, sp);
            if (dc.getTextWidthInPixels(s + "…", font) <= maxW) {
                return s + "…";
            }
            sp = lastSpaceAt(s);
        }
        // Single over-long word: cut by character.
        s = text;
        while (s.length() > 1) {
            s = s.substring(0, s.length() - 1);
            if (dc.getTextWidthInPixels(s + "…", font) <= maxW) {
                return s + "…";
            }
        }
        return "…";
    }

    function lastSpaceAt(s as Lang.String) as Lang.Number {
        var k = s.length() - 1;
        while (k > 0) {
            if (s.substring(k, k + 1).equals(" ")) {
                return k;
            }
            k--;
        }
        return 0;
    }

    //! Circle = the device SCREEN (not dc size): headers are drawn into bitmaps blitted at
    //! the screen origin, whose own size is not the circle. Steps the font down until the
    //! text fits its chord; ellipsis only as the last resort (never a mid-glyph clip).
    function drawCenteredInChord(dc as Graphics.Dc, y as Lang.Number, text as Lang.String,
                                 font as Graphics.FontType) as Void {
        var ds = System.getDeviceSettings();
        var w = ds.screenWidth;
        var h = ds.screenHeight;
        var useFont = font; // Dylan 4:39 PM: never step the font down; shift, then ellipsize
        // Still too wide near the top of the dial: slide down (<= 1/2 line, chord widens)
        // before ever ellipsizing (edge pass: "Song of Sol..", "1 Thessalo.." headers).
        var tw = dc.getTextWidthInPixels(text, useFont);
        var maxDy = dc.getFontHeight(useFont) / 2;
        var dy = 0;
        while (dy < maxDy && y + dy < h / 2) {
            var a = chordWidth(y + dy, w, h) - 8;
            if (tw <= a) {
                break;
            }
            dy += 2;
        }
        y += dy;
        var c0 = chordWidth(y + dc.getFontHeight(useFont), w, h) - 8;
        var c1 = chordWidth(y, w, h) - 8;
        var t = ellipsize(dc, text, useFont, c0 < c1 ? c0 : c1);
        dc.drawText(w / 2, y, useFont, t, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function shrinkFont(font as Graphics.FontType) as Graphics.FontDefinition {
        if (font == Graphics.FONT_MEDIUM) {
            return Graphics.FONT_SMALL;
        }
        if (font == Graphics.FONT_SMALL) {
            return Graphics.FONT_TINY;
        }
        if (font == Graphics.FONT_TINY) {
            return Graphics.FONT_XTINY;
        }
        return font;
    }

    function growFont(font as Graphics.FontType) as Graphics.FontDefinition {
        if (font == Graphics.FONT_XTINY) {
            return Graphics.FONT_TINY;
        }
        if (font == Graphics.FONT_TINY) {
            return Graphics.FONT_SMALL;
        }
        return font;
    }

    //! Progress arc along the bezel from 12 o'clock. progress in [0,1].
    function drawProgressArc(dc as Graphics.Dc, progress as Lang.Float, bookmarkFracs as Lang.Array) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (!isRound()) {
            var m = edgeMargin(w, h);
            var barW = ((w - 2 * m) * progress).toNumber();
            dc.setColor(Palette.GOLD, Palette.BG);
            dc.fillRectangle(m, m / 2, barW < 1 ? 1 : barW, 2);
            return;
        }
        // POKE: PROGRESS_ARC — thickness 3px, start 12 o'clock, clockwise, full ring
        // (set PROGRESS_ARC_GAP_DEG > 0 for a gap centered at 6 o'clock), radius-2 bezel ring.
        var cx = w / 2;
        var cy = h / 2;
        var pen = PROGRESS_ARC_PEN;
        var rad = (w < h ? w : h) / 2 - 2 - pen / 2;
        if (progress < 0) {
            progress = 0.0;
        }
        if (progress > 1) {
            progress = 1.0;
        }
        var span = 360 - PROGRESS_ARC_GAP_DEG;
        var startDeg = 90; // CIQ degrees: 0 = 3 o'clock, CCW positive -> 90 = 12 o'clock
        dc.setPenWidth(pen);
        // Dim track (~20% gold) under the fill.
        dc.setColor(Palette.PROGRESS_TRACK, Graphics.COLOR_TRANSPARENT);
        if (PROGRESS_ARC_GAP_DEG <= 0) {
            dc.drawCircle(cx, cy, rad);
        } else {
            dc.drawArc(cx, cy, rad, Graphics.ARC_CLOCKWISE, startDeg, startDeg - span);
        }
        var sweep = (span * progress).toNumber();
        if (sweep < 2 && progress > 0) {
            sweep = 2;
        }
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        if (sweep >= 360) {
            dc.drawCircle(cx, cy, rad);
        } else if (sweep > 0) {
            dc.drawArc(cx, cy, rad, Graphics.ARC_CLOCKWISE, startDeg, startDeg - sweep);
        }
        // Bookmark ticks across the ring, clockwise from 12.
        dc.setPenWidth(1);
        var i;
        for (i = 0; i < bookmarkFracs.size(); i++) {
            var f = bookmarkFracs[i] as Lang.Float;
            if (f < 0 || f > 1) {
                continue;
            }
            var deg = 90.0 - span * f;
            var theta = deg * Math.PI / 180.0;
            var x1 = cx + ((rad - 5) * Math.cos(theta)).toNumber();
            var y1 = cy - ((rad - 5) * Math.sin(theta)).toNumber();
            var x2 = cx + ((rad + 1) * Math.cos(theta)).toNumber();
            var y2 = cy - ((rad + 1) * Math.sin(theta)).toNumber();
            dc.drawLine(x1, y1, x2, y2);
        }
        dc.setPenWidth(1);
    }

    //! Full-screen solid scrim + single centered gold pill. No gray band, no body bleed.
    function drawToastPill(dc as Graphics.Dc, message as Lang.String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // No solid fill: caller redraws the reader in Palette.TOAST_DIM first (dim, not blackout).

        var label = message;
        var iconW = 10;
        var iconGap = 6;
        var font = Graphics.FONT_TINY;
        var tw = dc.getTextWidthInPixels(label, font);
        var padX = 14;
        var padY = 8;
        var boxH = dc.getFontHeight(font) + 2 * padY;
        var boxW = tw + iconW + iconGap + 2 * padX;
        var maxW = (w * 0.72).toNumber();
        if (boxW > maxW) {
            boxW = maxW;
        }
        if (boxW < 48) {
            boxW = 48;
        }
        var boxX = (w - boxW) / 2;
        var boxY = (h - boxH) / 2;
        var cy = h / 2;
        var endR = boxH / 2;
        var innerW = boxW - boxH;
        if (innerW < 1) {
            innerW = 1;
        }

        dc.setColor(Palette.TOAST_PILL, Palette.BG);
        dc.fillRectangle(boxX + endR, boxY, innerW, boxH);
        dc.fillCircle(boxX + endR, cy, endR);
        dc.fillCircle(boxX + boxW - endR, cy, endR);

        dc.setColor(Palette.TOAST_FG, Graphics.COLOR_TRANSPARENT);
        var contentX = (w - (iconW + iconGap + tw)) / 2;
        var iconH = dc.getFontHeight(font) - 6;
        var iy = cy - iconH / 2;
        // Bookmark ribbon: rectangle with a V notch at the bottom.
        dc.fillPolygon([[contentX, iy], [contentX + iconW, iy], [contentX + iconW, iy + iconH],
            [contentX + iconW / 2, iy + iconH - 4], [contentX, iy + iconH]]);
        dc.drawText(contentX + iconW + iconGap, boxY + padY, font, label, Graphics.TEXT_JUSTIFY_LEFT);
    }

    //! Greedy word wrap into at most maxRows rows of width <= room; if words remain, the last
    //! row ends at a word with "…" (never inside a word unless one word alone is too wide).
    function wrapRows(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontType,
                      room as Lang.Number, maxRows as Lang.Number) as Lang.Array {
        var words = ContentLoader.splitWords(text);
        var rows = [] as Lang.Array;
        var cur = "";
        var i = 0;
        while (i < words.size() && rows.size() < maxRows) {
            var cand = cur.length() == 0 ? words[i] as Lang.String : cur + " " + words[i];
            if (cur.length() == 0 || dc.getTextWidthInPixels(cand, font) <= room) {
                cur = cand;
                i++;
            } else {
                rows.add(cur);
                cur = "";
            }
        }
        if (cur.length() > 0 && rows.size() < maxRows) {
            rows.add(cur);
        }
        if (i < words.size() && rows.size() > 0) {
            rows[rows.size() - 1] = ellipsize(dc, (rows[rows.size() - 1] as Lang.String) + " " + words[i], font, room);
            var last = rows[rows.size() - 1] as Lang.String;
            if (!last.substring(last.length() - 1, last.length()).equals("…")) {
                rows[rows.size() - 1] = ellipsize(dc, last + " …", font, room);
            }
        }
        return rows;
    }
}
