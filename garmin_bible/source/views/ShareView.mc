using Toybox.Graphics;
using Toybox.Communications;
import Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Application;

class ShareView extends Ui.View {
    var url as String = "";
    var qrBitmap as Graphics.BitmapReference? = null;
    var isLoading as Boolean = true;
    var hasError as Boolean = false;
    var qrSize as Number = 120;
    var requestStarted as Boolean = false;
    var isAlive as Boolean;

    function initialize(passageUrl as String) {
        View.initialize();
        url = passageUrl;
        qrBitmap = null;
        isLoading = true;
        hasError = false;
        qrSize = 120;
        requestStarted = false;
        isAlive = true;
    }

    function onShow() as Void {
        isLoading = true;
        hasError = false;
        qrBitmap = null;
        requestStarted = false;
        isAlive = true;
    }

    function onQrImageResponse(
        responseCode as Number,
        data as Graphics.BitmapReference or Ui.BitmapResource or Null
    ) as Void {
        if (!isAlive) {
            return;
        }
        if (responseCode == 200 && data != null) {
            qrBitmap = data as Graphics.BitmapReference;
            isLoading = false;
            hasError = false;
        } else {
            qrBitmap = null;
            isLoading = false;
            hasError = true;
        }
        Ui.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Start image request on first update if not yet started
        if (!requestStarted) {
            requestStarted = true;
            qrSize = BibleShare.computeQrSize(width, height);
            var qrImageUrl = BibleShare.buildQrImageUrl(url, qrSize);
            Communications.makeImageRequest(
                qrImageUrl,
                null,
                { :maxWidth => qrSize, :maxHeight => qrSize },
                method(:onQrImageResponse)
            );
        }

        var layout = BibleLayout.computeLayout(dc);
        var bgColor = layout.get("bgColor") as Number;
        var textColor = layout.get("textColor") as Number;
        var fontSize = layout.get("fontSize") as Number;

        // Clear background
        dc.setColor(textColor, bgColor);
        dc.clear();

        if (isLoading) {
            BibleLayout.drawMessage(dc, layout, WatchUi.loadResource(Rez.Strings.Loading) as String);
            return;
        }

        if (qrBitmap != null) {
            // Draw QR bitmap centered
            var bitmapW = qrBitmap.getWidth();
            var bitmapH = qrBitmap.getHeight();
            var x = (width - bitmapW) / 2;
            var y = (height - bitmapH) / 2 - 10;
            if (y < 14) {
                y = 14; // keep below header area
            }
            dc.drawBitmap(x, y, qrBitmap);

            // Draw URL text below the QR code
            var urlY = y + bitmapH + 4;
            if (urlY + 10 < height) {
                dc.setColor(textColor, bgColor);
                var displayUrl = truncateUrl(url, width - 8, fontSize);
                var font;
                if (fontSize == BibleLayout.FONT_LARGE) {
                    font = Graphics.FONT_LARGE;
                } else if (fontSize == BibleLayout.FONT_MEDIUM) {
                    font = Graphics.FONT_MEDIUM;
                } else if (fontSize == BibleLayout.FONT_TINY) {
                    font = Graphics.FONT_TINY;
                } else {
                    font = Graphics.FONT_SMALL;
                }
                dc.drawText(4, urlY, font, displayUrl, Graphics.TEXT_JUSTIFY_LEFT);
            }
        } else {
            // Fallback: no QR bitmap — show URL text with hint
            var hint = WatchUi.loadResource(Rez.Strings.ScanWithPhone) as String;
            BibleLayout.drawMessage(dc, layout, hint + "\n" + url);
        }
    }

    private function truncateUrl(original as String, maxWidthPx as Number, fontSize as Number) as String {
        var charWidth = BibleLayout.getCharWidthForFontSize(fontSize);
        var maxChars = maxWidthPx / charWidth;
        if (maxChars < 1) {
            maxChars = 1;
        }
        if (original.length() <= maxChars) {
            return original;
        }
        if (maxChars > 3) {
            var sub = original.substring(0, maxChars - 3);
            if (sub != null) {
                return sub + "...";
            }
            return original;
        }
        var sub2 = original.substring(0, maxChars);
        if (sub2 != null) {
            return sub2;
        }
        return original;
    }

    function onHide() as Void {
        isAlive = false;
        // Release bitmap memory
        qrBitmap = null;
    }
}
