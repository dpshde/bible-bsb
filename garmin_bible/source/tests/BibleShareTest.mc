import Toybox.Lang;
using Toybox.Test;

(:test)
class BibleShareTest {

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private function makeState(bookIndex as Number, chapter as Number,
                                 startVerse as Number, endVerse as Number) as BibleState {
        var state = new BibleState();
        state.bookIndex = bookIndex;
        state.chapter = chapter;
        state.startVerse = startVerse;
        state.endVerse = endVerse;
        return state;
    }

    // -----------------------------------------------------------------------
    // URL construction — single verse
    // -----------------------------------------------------------------------

    function testBuildUrlSingleVerse(logger as Test.Logger) as Boolean {
        var state = makeState(42, 3, 16, 16); // John 3:16
        var url = BibleShare.buildUrl(state);
        return url == "https://route.bible/jhn.3.16?v=BSB&src=kindled_spark";
    }

    function testBuildUrlGenesis1_1(logger as Test.Logger) as Boolean {
        var state = makeState(0, 1, 1, 1); // Genesis 1:1
        var url = BibleShare.buildUrl(state);
        return url == "https://route.bible/gen.1.1?v=BSB&src=kindled_spark";
    }

    function testBuildUrlPsalm23_1(logger as Test.Logger) as Boolean {
        var state = makeState(18, 23, 1, 1); // Psalm 23:1
        var url = BibleShare.buildUrl(state);
        return url == "https://route.bible/psa.23.1?v=BSB&src=kindled_spark";
    }

    function testBuildUrlRevelation22_21(logger as Test.Logger) as Boolean {
        var state = makeState(65, 22, 21, 21); // Revelation 22:21
        var url = BibleShare.buildUrl(state);
        return url == "https://route.bible/rev.22.21?v=BSB&src=kindled_spark";
    }

    function testBuildUrl1Samuel1_1(logger as Test.Logger) as Boolean {
        var state = makeState(8, 1, 1, 1); // 1 Samuel 1:1
        var url = BibleShare.buildUrl(state);
        return url == "https://route.bible/1sa.1.1?v=BSB&src=kindled_spark";
    }

    // -----------------------------------------------------------------------
    // URL construction — verse range
    // -----------------------------------------------------------------------

    function testBuildUrlRange(logger as Test.Logger) as Boolean {
        var state = makeState(42, 3, 16, 18); // John 3:16-18
        var url = BibleShare.buildUrl(state);
        return url == "https://route.bible/jhn.3.16-jhn.3.18?v=BSB&src=kindled_spark";
    }

    function testBuildUrlGenesis1Range(logger as Test.Logger) as Boolean {
        var state = makeState(0, 1, 1, 5); // Genesis 1:1-5
        var url = BibleShare.buildUrl(state);
        return url == "https://route.bible/gen.1.1-gen.1.5?v=BSB&src=kindled_spark";
    }

    function testBuildUrlPsalm119Range(logger as Test.Logger) as Boolean {
        var state = makeState(18, 119, 1, 176); // Psalm 119:1-176
        var url = BibleShare.buildUrl(state);
        return url == "https://route.bible/psa.119.1-psa.119.176?v=BSB&src=kindled_spark";
    }

    // -----------------------------------------------------------------------
    // URL construction — full chapter (no verse suffix)
    // -----------------------------------------------------------------------

    function testBuildUrlFullChapter(logger as Test.Logger) as Boolean {
        var state = makeState(42, 3, 1, 36); // John 3 (full chapter)
        var url = BibleShare.buildUrl(state);
        // start=1, end=36, so it's a range format
        return url == "https://route.bible/jhn.3.1-jhn.3.36?v=BSB&src=kindled_spark";
    }

    // -----------------------------------------------------------------------
    // QR image URL construction
    // -----------------------------------------------------------------------

    function testBuildQrImageUrl(logger as Test.Logger) as Boolean {
        var dataUrl = "https://route.bible/jhn.3.16?v=BSB&src=kindled_spark";
        var qrUrl = BibleShare.buildQrImageUrl(dataUrl, 120);
        return qrUrl == "https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=https://route.bible/jhn.3.16?v=BSB&src=kindled_spark";
    }

    function testBuildQrImageUrlSize160(logger as Test.Logger) as Boolean {
        var dataUrl = "https://route.bible/gen.1.1?v=BSB";
        var qrUrl = BibleShare.buildQrImageUrl(dataUrl, 160);
        return qrUrl == "https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=https://route.bible/gen.1.1?v=BSB";
    }

    // -----------------------------------------------------------------------
    // QR size computation
    // -----------------------------------------------------------------------

    function testComputeQrSizeSmallScreen(logger as Test.Logger) as Boolean {
        var size = BibleShare.computeQrSize(176, 176);
        return size == 120;
    }

    function testComputeQrSizeMediumScreen(logger as Test.Logger) as Boolean {
        var size = BibleShare.computeQrSize(218, 218);
        return size == 160;
    }

    function testComputeQrSizeLargeScreen(logger as Test.Logger) as Boolean {
        var size = BibleShare.computeQrSize(390, 390);
        return size == 200;
    }

    function testComputeQrSizeNarrowHeight(logger as Test.Logger) as Boolean {
        var size = BibleShare.computeQrSize(260, 100);
        return size == 120;
    }

    // -----------------------------------------------------------------------
    // URL contains expected components for all 66 books
    // -----------------------------------------------------------------------

    function testUrlContainsOsisForAllBooks(logger as Test.Logger) as Boolean {
        for (var i = 0; i < BibleBooks.BOOK_COUNT; i++) {
            var state = makeState(i, 1, 1, 1);
            var url = BibleShare.buildUrl(state);
            var osis = BibleBooks.getOsisCode(i);
            var osisIdx = url.find(osis);
            if (osisIdx == null) {
                return false;
            }
            var routeIdx = url.find("route.bible");
            if (routeIdx == null) {
                return false;
            }
            var verIdx = url.find("v=BSB");
            if (verIdx == null) {
                return false;
            }
        }
        return true;
    }

    // -----------------------------------------------------------------------
    // URL is lowercase
    // -----------------------------------------------------------------------

    function testUrlIsLowercase(logger as Test.Logger) as Boolean {
        var state = makeState(42, 3, 16, 16);
        var url = BibleShare.buildUrl(state);
        // Verify no uppercase letters in the path portion
        var pathStart = url.find("route.bible/");
        if (pathStart == null) {
            return false;
        }
        var idx = pathStart + "route.bible/".length();
        var queryIdx = url.find("?");
        while (idx < url.length()) {
            var ch = url.substring(idx, idx + 1);
            if (ch == null) {
                break;
            }
            var chStr = ch as String;
            var code = chStr.toNumber();
            if (code != null && code >= 65 && code <= 90) {
                // Found uppercase A-Z in path — only allowed in query param values
                if (queryIdx == null || idx < queryIdx) {
                    return false;
                }
            }
            idx = idx + 1;
        }
        return true;
    }
}
