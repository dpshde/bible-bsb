using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;

//! Round/square safe geometry for Enduro 3 and budget lines.
module RoundLayout {

    // POKE: READER_LAYOUT — RECT = straight left column (default); CENTERED_CHORD = each line centered on its chord.
    enum {
        READER_LAYOUT_RECT = 0,
        READER_LAYOUT_CENTERED_CHORD = 1
    }
    const READER_LAYOUT = READER_LAYOUT_RECT;

    // POKE: soft max column width as fraction of screen (~0.82). Floor asserted in tests: 0.72.
    const COLUMN_WIDTH_FRAC = 0.80;
    const COLUMN_WIDTH_MIN_FRAC = 0.72;

    // POKE: pixel pad inside the inscribed chord (NOT a second % of radius — that crushed RECT to ~40%).
    const COLUMN_PIXEL_PAD = 6;

    // Vertical band for width math on round screens (avoids near-bezel chords).
    // POKE: 0.22..0.86 keeps inscribed width >= ~72% on 280 round (0.88 crushed the chord).
    const COLUMN_BAND_TOP_FRAC = 0.22;
    const COLUMN_BAND_BOTTOM_FRAC = 0.86;

    // POKE: chord margin as fraction of radius (CENTERED_CHORD path only).
    const CHORD_MARGIN_FRAC = 0.07;

    // POKE: edge margin fraction of min(w,h) for square screens and as a floor on round.
    const EDGE_MARGIN_FRAC = 0.06;

    // POKE: blank spacer lines above/below continuation divider.
    const DIVIDER_PAD_LINES = 1;

    // POKE: toast / mode-banner auto-dismiss milliseconds (~1s).
    const TOAST_MS = 1000;

    // POKE: mode change feedback — transient centered label only (no permanent V/L chip).
    // Alternatives later: tiny icon in header safe area.
    const MODE_BANNER_ONLY = true;

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

    //! Usable text width in pixels for a line whose vertical center is at y.
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
        var r2 = r * r;
        var dy2 = dy * dy;
        if (dy2 >= r2) {
            return 1;
        }
        var half = Math.sqrt(r2 - dy2) - (r * CHORD_MARGIN_FRAC);
        if (half < 1.0) {
            half = 1.0;
        }
        var cw = (half * 2.0).toNumber();
        if (cw > maxW) {
            cw = maxW;
        }
        if (cw < 1) {
            cw = 1;
        }
        return cw;
    }

    function chordLeft(y as Lang.Number, width as Lang.Number, height as Lang.Number) as Lang.Number {
        return (width - chordWidth(y, width, height)) / 2;
    }

    function minChordInBand(y0 as Lang.Number, y1 as Lang.Number, width as Lang.Number, height as Lang.Number) as Lang.Number {
        var a = chordWidth(y0, width, height);
        var b = chordWidth((y0 + y1) / 2, width, height);
        var c = chordWidth(y1, width, height);
        var m = a;
        if (b < m) {
            m = b;
        }
        if (c < m) {
            m = c;
        }
        return m;
    }

    //! Inscribed reader column: straight left/right edges, horizontally centered.
    //! Returns { :left, :width, :top, :bottom }.
    //! Round width = 2*sqrt(r^2 - hLimit^2) - 2*COLUMN_PIXEL_PAD, with the band
    //! clamped to ~[0.22H, 0.88H] so a near-bezel bottom does not crush the column.
    //! Square: full width minus edge margins.
    function columnRect(width as Lang.Number, height as Lang.Number,
                        contentTop as Lang.Number, contentBottom as Lang.Number) as Lang.Dictionary {
        var top = contentTop;
        var bottom = contentBottom;
        if (bottom <= top + 1) {
            bottom = top + 1;
        }

        if (!isRound()) {
            var m = edgeMargin(width, height);
            var sqW = width - 2 * m;
            if (sqW < 1) {
                sqW = 1;
            }
            return { :left => m, :width => sqW, :top => top, :bottom => bottom };
        }

        // Clamp vertical extents used for inscription (reading band, not full bezel-to-bezel).
        var bandTop = (height * COLUMN_BAND_TOP_FRAC).toNumber();
        var bandBot = (height * COLUMN_BAND_BOTTOM_FRAC).toNumber();
        if (top < bandTop) {
            top = bandTop;
        }
        if (bottom > bandBot) {
            bottom = bandBot;
        }
        if (bottom <= top + 1) {
            bottom = top + 1;
        }

        var colW = inscribedColumnWidth(width, height, top, bottom);
        var left = (width - colW) / 2;
        return { :left => left, :width => colW, :top => top, :bottom => bottom };
    }

    //! Pure circle math (no screenShape): width = 2*sqrt(r^2 - h^2) - 2*pad
    //! where h = max distance from center to [contentTop, contentBottom].
    //! Soft-capped to COLUMN_WIDTH_FRAC; never below COLUMN_WIDTH_MIN_FRAC when geometry allows.
    function inscribedColumnWidth(screenW as Lang.Number, screenH as Lang.Number,
                                  contentTop as Lang.Number, contentBottom as Lang.Number) as Lang.Number {
        var r = (screenW < screenH ? screenW : screenH) / 2.0;
        var cy = screenH / 2.0;
        var dTop = contentTop.toFloat() - cy;
        if (dTop < 0) {
            dTop = -dTop;
        }
        var dBot = contentBottom.toFloat() - cy;
        if (dBot < 0) {
            dBot = -dBot;
        }
        var hLimit = dTop;
        if (dBot > hLimit) {
            hLimit = dBot;
        }
        // If the band still reaches too close to the rim, pull hLimit in so width stays readable.
        // Target at least COLUMN_WIDTH_MIN_FRAC when r allows it.
        var minW = screenW * COLUMN_WIDTH_MIN_FRAC;
        var halfMin = minW / 2.0 + COLUMN_PIXEL_PAD;
        if (halfMin < r) {
            var maxH = Math.sqrt(r * r - halfMin * halfMin);
            if (hLimit > maxH) {
                hLimit = maxH;
            }
        }
        if (hLimit >= r) {
            hLimit = r * 0.85;
        }
        var half = Math.sqrt(r * r - hLimit * hLimit) - COLUMN_PIXEL_PAD;
        if (half < 1.0) {
            half = 1.0;
        }
        var colW = (half * 2.0).toNumber();
        var maxW = (screenW * COLUMN_WIDTH_FRAC).toNumber();
        if (colW > maxW) {
            colW = maxW;
        }
        var floorW = (screenW * COLUMN_WIDTH_MIN_FRAC).toNumber();
        if (colW < floorW) {
            colW = floorW;
        }
        return colW;
    }

    //! @deprecated Use inscribedColumnWidth; kept for older tests.
    function maxCenteredColumnWidth(screenW as Lang.Number, screenH as Lang.Number,
                                     contentTop as Lang.Number, contentBottom as Lang.Number,
                                     chordMarginFrac as Lang.Float) as Lang.Number {
        return inscribedColumnWidth(screenW, screenH, contentTop, contentBottom);
    }

    function drawCenteredInChord(dc as Graphics.Dc, y as Lang.Number, text as Lang.String, font as Lang.Number) as Void {
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

    function shrinkFont(font as Lang.Number) as Lang.Number {
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

    //! Dim backdrop + centered rounded pill; width follows column when RECT layout.
    function drawToastPill(dc as Graphics.Dc, message as Lang.String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cy = h / 2;
        var col = columnRect(w, h, cy - 30, cy + 30);
        var maxW = col[:width] as Lang.Number;
        var bandLeft = col[:left] as Lang.Number;

        // Dim behind the pill so it cannot blend into the reader on the first frame.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_WHITE);
        dc.fillRectangle(bandLeft, cy - 24, maxW, 48);

        var label = "★ " + message;
        var font = Graphics.FONT_TINY;
        var tw = dc.getTextWidthInPixels(label, font);
        var padX = 14;
        var padY = 8;
        var boxW = tw + 2 * padX;
        if (boxW > maxW - 8) {
            boxW = maxW - 8;
        }
        if (boxW < 48) {
            boxW = 48;
        }
        var boxH = dc.getFontHeight(font) + 2 * padY;
        var boxX = (w - boxW) / 2;
        var boxY = cy - boxH / 2;
        var endR = boxH / 2;
        var innerW = boxW - boxH;
        if (innerW < 1) {
            innerW = 1;
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(boxX + endR, boxY, innerW, boxH);
        dc.fillCircle(boxX + endR, cy, endR);
        dc.fillCircle(boxX + boxW - endR, cy, endR);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, boxY + padY, font, label, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
