using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;

//! Round/square safe geometry for Enduro 3 and budget lines.
//! Chord math: usable width at row y is 2*(sqrt(r^2-(y-cy)^2) - margin).
module RoundLayout {

    // POKE: chord margin as fraction of radius after Enduro 3 reshoot (try 0.06..0.08).
    const CHORD_MARGIN_FRAC = 0.07;

    // POKE: edge margin fraction of min(w,h) for square screens and as a floor on round.
    const EDGE_MARGIN_FRAC = 0.06;

    // POKE: blank spacer lines above/below continuation divider (Flipper had no continuation).
    const DIVIDER_PAD_LINES = 1;

    // POKE: toast auto-dismiss milliseconds (Dylan: ~1s).
    const TOAST_MS = 1000;

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
    //! Square: full width minus edge margins. Round: circle chord minus chord margin.
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
        // POKE: chord margin constant — tighten if still clipped on FR165/VA5.
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

    //! Minimum chord inside [y0, y1] sampled at ends + mid (stable reader wrap).
    //! POKE: replace with screen-y reflow if mid-band density matters more than scroll-stable lines.
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

    //! Draw text centered on the row, shrinking font one step if needed to fit the chord.
    function drawCenteredInChord(dc as Graphics.Dc, y as Lang.Number, text as Lang.String, font as Lang.Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var midY = y + dc.getFontHeight(font) / 2;
        var cw = chordWidth(midY, w, h);
        var useFont = font;
        if (dc.getTextWidthInPixels(text, useFont) > cw) {
            useFont = shrinkFont(useFont);
        }
        // If still too wide, clip by chord — never abbreviate book names in callers.
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

    //! Dim backdrop + centered rounded pill toast with optional leading mark.
    function drawToastPill(dc as Graphics.Dc, message as Lang.String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cy = h / 2;
        var cw = chordWidth(cy, w, h);
        var left = chordLeft(cy, w, h);

        // Obscure underlying text in the toast band.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_LT_GRAY);
        dc.setClip(left, cy - 22, cw, 44);
        dc.fillRectangle(left, cy - 22, cw, 44);
        dc.clearClip();

        var label = "★ " + message;
        var font = Graphics.FONT_TINY;
        var tw = dc.getTextWidthInPixels(label, font);
        var padX = 14;
        var padY = 8;
        var boxW = tw + 2 * padX;
        if (boxW > cw - 8) {
            boxW = cw - 8;
        }
        var boxH = dc.getFontHeight(font) + 2 * padY;
        var boxX = (w - boxW) / 2;
        var boxY = cy - boxH / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        // Soft rounded look: filled rect + side circles (CIQ has no fillRoundedRectangle on older API).
        dc.fillRectangle(boxX + boxH / 2, boxY, boxW - boxH, boxH);
        dc.fillCircle(boxX + boxH / 2, cy, boxH / 2);
        dc.fillCircle(boxX + boxW - boxH / 2, cy, boxH / 2);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, boxY + padY, font, label, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
