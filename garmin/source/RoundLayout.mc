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
    function pyramidSplit(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition,
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

    //! Last-resort two lines: pyramid-split with line 2 unbounded, then ellipsize line 2 only.
    function pyramidSplitEllipsize(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition,
                                   w1 as Lang.Number, w2 as Lang.Number) as Lang.Array {
        var parts = pyramidSplit(dc, text, font, w1, 100000);
        if (parts == null) {
            parts = ["", text];
        }
        parts[1] = ellipsize(dc, parts[1] as Lang.String, font, w2);
        return parts;
    }

    function ellipsize(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition,
                       maxW as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(text, font) <= maxW) {
            return text;
        }
        var s = text;
        while (s.length() > 1) {
            s = s.substring(0, s.length() - 1);
            if (dc.getTextWidthInPixels(s + "..", font) <= maxW) {
                return s + "..";
            }
        }
        return "..";
    }

    function drawCenteredInChord(dc as Graphics.Dc, y as Lang.Number, text as Lang.String,
                                 font as Graphics.FontDefinition) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var midY = y + dc.getFontHeight(font) / 2;
        var cw = chordWidth(midY, w, h);
        var useFont = font;
        if (dc.getTextWidthInPixels(text, useFont) > cw) {
            useFont = shrinkFont(useFont);
        }
        var left = chordLeft(midY, w, h);
        dc.setClip(left, y - 1, cw, dc.getFontHeight(useFont) + 2);
        dc.drawText(w / 2, y, useFont, text, Graphics.TEXT_JUSTIFY_CENTER);
        dc.clearClip();
    }

    function shrinkFont(font as Graphics.FontDefinition) as Graphics.FontDefinition {
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

    function growFont(font as Graphics.FontDefinition) as Graphics.FontDefinition {
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
}
