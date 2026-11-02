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

    // POKE: target column width as fraction of screen width (~0.80 per Dylan).
    const COLUMN_WIDTH_FRAC = 0.80;

    // POKE: chord margin as fraction of radius (CENTERED_CHORD / safe capping).
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
    //! Round: ~COLUMN_WIDTH_FRAC of screen width, capped so the rect stays inside the
    //! circle for the whole [contentTop, contentBottom] band.
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

        var target = (width * COLUMN_WIDTH_FRAC).toNumber();
        // Cap by the narrowest safe chord in the content band (minus a small pad).
        var safe = minChordInBand(top, bottom, width, height) - 4;
        if (safe < 1) {
            safe = 1;
        }
        var colW = target;
        if (colW > safe) {
            colW = safe;
        }
        var left = (width - colW) / 2;
        return { :left => left, :width => colW, :top => top, :bottom => bottom };
    }

    //! Pure math helper for tests (no screenShape): largest centered width fitting a circle band.
    function maxCenteredColumnWidth(screenW as Lang.Number, screenH as Lang.Number,
                                     contentTop as Lang.Number, contentBottom as Lang.Number,
                                     chordMarginFrac as Lang.Float) as Lang.Number {
        var r = (screenW < screenH ? screenW : screenH) / 2.0;
        var cy = screenH / 2.0;
        var samples = [contentTop, (contentTop + contentBottom) / 2, contentBottom] as Lang.Array;
        var minHalf = r;
        var i;
        for (i = 0; i < samples.size(); i++) {
            var y = (samples[i] as Lang.Number).toFloat();
            var dy = y - cy;
            var inside = r * r - dy * dy;
            if (inside <= 0) {
                return 1;
            }
            var half = Math.sqrt(inside) - (r * chordMarginFrac);
            if (half < minHalf) {
                minHalf = half;
            }
        }
        if (minHalf < 1.0) {
            minHalf = 1.0;
        }
        return (minHalf * 2.0).toNumber();
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

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_LT_GRAY);
        dc.setClip(bandLeft, cy - 22, maxW, 44);
        dc.fillRectangle(bandLeft, cy - 22, maxW, 44);
        dc.clearClip();

        var label = "★ " + message;
        var font = Graphics.FONT_TINY;
        var tw = dc.getTextWidthInPixels(label, font);
        var padX = 14;
        var padY = 8;
        var boxW = tw + 2 * padX;
        if (boxW > maxW - 8) {
            boxW = maxW - 8;
        }
        var boxH = dc.getFontHeight(font) + 2 * padY;
        var boxX = (w - boxW) / 2;
        var boxY = cy - boxH / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(boxX + boxH / 2, boxY, boxW - boxH, boxH);
        dc.fillCircle(boxX + boxH / 2, cy, boxH / 2);
        dc.fillCircle(boxX + boxW - boxH / 2, cy, boxH / 2);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, boxY + padY, font, label, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
