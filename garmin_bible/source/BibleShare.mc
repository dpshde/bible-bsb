import Toybox.Lang;
using Toybox.Communications;
using Toybox.System;
using Toybox.WatchUi as Ui;

module BibleShare {
    const ROUTE_BASE = "https://route.bible";
    const TRANSLATION = "BSB";
    const SOURCE_TAG = "kindled_spark";

    // Build a canonical route.bible URL from passage state.
    // Single verse: https://route.bible/{osis}.{chapter}.{verse}?v=BSB&src=kindled_spark
    // Range:       https://route.bible/{osis}.{chapter}.{start}-{osis}.{chapter}.{end}?v=BSB&src=kindled_spark
    function buildUrl(state as BibleState) as String {
        var osis = BibleBooks.getOsisCode(state.bookIndex);
        var url = ROUTE_BASE + "/" + osis + "." + state.chapter;
        if (state.startVerse > 0) {
            url = url + "." + state.startVerse;
            if (state.endVerse > state.startVerse) {
                url = url + "-" + osis + "." + state.chapter + "." + state.endVerse;
            }
        }
        url = url + "?v=" + TRANSLATION + "&src=" + SOURCE_TAG;
        return url;
    }

    // Build the QR-server image-request URL for a given data URL and pixel size.
    // Example: https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=URL
    function buildQrImageUrl(dataUrl as String, size as Number) as String {
        return "https://api.qrserver.com/v1/create-qr-code/?size=" + size + "x" + size + "&data=" + dataUrl;
    }

    // Compute an appropriate QR-code pixel size for the given screen dimensions.
    // 120x120 on 176x176, 160x160 up to 260x260, 200x200 above.
    function computeQrSize(screenWidth as Number, screenHeight as Number) as Number {
        var minDim = screenWidth < screenHeight ? screenWidth : screenHeight;
        if (minDim <= 180) {
            return 120;
        } else if (minDim <= 260) {
            return 160;
        } else {
            return 200;
        }
    }
}
