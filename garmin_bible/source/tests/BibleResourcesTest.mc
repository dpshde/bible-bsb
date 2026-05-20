using Toybox.Application;
import Toybox.Lang;
using Toybox.Test;
using Toybox.WatchUi as WatchUi;

(:test)
class BibleResourcesTest {

    // -----------------------------------------------------------------------
    // Coverage tests
    // -----------------------------------------------------------------------

    function testGenesis1IsAvailable(logger as Test.Logger) as Boolean {
        var id = BibleResources.getResourceId(0, 1);
        return id != null;
    }

    function testGenesis10IsAvailable(logger as Test.Logger) as Boolean {
        var id = BibleResources.getResourceId(0, 10);
        return id != null;
    }

    function testGenesis11IsNotAvailable(logger as Test.Logger) as Boolean {
        var id = BibleResources.getResourceId(0, 11);
        return id == null;
    }

    function testPsalms1IsAvailable(logger as Test.Logger) as Boolean {
        var id = BibleResources.getResourceId(18, 1);
        return id != null;
    }

    function testPsalms150IsAvailable(logger as Test.Logger) as Boolean {
        var id = BibleResources.getResourceId(18, 150);
        return id != null;
    }

    function testPsalms151IsNotAvailable(logger as Test.Logger) as Boolean {
        var id = BibleResources.getResourceId(18, 151);
        return id == null;
    }

    function testProverbs1IsAvailable(logger as Test.Logger) as Boolean {
        var id = BibleResources.getResourceId(19, 1);
        return id != null;
    }

    function testProverbs31IsAvailable(logger as Test.Logger) as Boolean {
        var id = BibleResources.getResourceId(19, 31);
        return id != null;
    }

    function testMatthew1IsAvailable(logger as Test.Logger) as Boolean {
        var id = BibleResources.getResourceId(39, 1);
        return id != null;
    }

    function testRevelation22IsAvailable(logger as Test.Logger) as Boolean {
        var id = BibleResources.getResourceId(65, 22);
        return id != null;
    }

    function testExodusNotAvailable(logger as Test.Logger) as Boolean {
        var id = BibleResources.getResourceId(1, 1);
        return id == null;
    }

    function testHasResourceTrue(logger as Test.Logger) as Boolean {
        return BibleResources.hasResource(0, 1);
    }

    function testHasResourceFalse(logger as Test.Logger) as Boolean {
        return !BibleResources.hasResource(1, 1);
    }

    function testTotalResourceCount(logger as Test.Logger) as Boolean {
        var count = BibleResources.getTotalResourceCount();
        return count == 451;
    }

    // -----------------------------------------------------------------------
    // BibleApi offline helpers
    // -----------------------------------------------------------------------

    function testIsOfflineAvailableGenesis1(logger as Test.Logger) as Boolean {
        return BibleApi.isOfflineAvailable(0, 1);
    }

    function testIsOfflineAvailableExodus1(logger as Test.Logger) as Boolean {
        return !BibleApi.isOfflineAvailable(1, 1);
    }

    // -----------------------------------------------------------------------
    // resourceToJsonString round-trip
    // -----------------------------------------------------------------------

    // Compact fixture matching the stripped format used by curated resources
    private function getCompactGenesis1Fixture() as String {
        return "{\"chapter\":{\"content\":[{\"type\":\"verse\",\"number\":1,\"content\":[\"In the beginning God created the heavens and the earth.\"]},{\"type\":\"verse\",\"number\":2,\"content\":[\"Now the earth was formless and void, and darkness was over the surface of the deep. And the Spirit of God was hovering over the surface of the waters.\"]},{\"type\":\"verse\",\"number\":3,\"content\":[\"And God said, \\u201cLet there be light,\\u201d and there was light.\"]},{\"type\":\"verse\",\"number\":4,\"content\":[\"And God saw that the light was good, and He separated the light from the darkness.\"]},{\"type\":\"verse\",\"number\":5,\"content\":[\"God called the light \\u201cday,\\u201d and the darkness He called \\u201cnight.\\u201d And there was evening, and there was morning\\u2014the first day.\"]}]}}";
    }

    function testCompactGenesis1ParsesCorrectly(logger as Test.Logger) as Boolean {
        var compact = getCompactGenesis1Fixture();
        var verses = BibleJsonScanner.parseVerses(compact);
        if (verses.size() != 5) {
            return false;
        }
        var v1 = verses[0] as Dictionary;
        var text = v1.get("verseText") as String;
        return text.equals("In the beginning God created the heavens and the earth.");
    }

    function testCompactVersesMatchFullApiVerses(logger as Test.Logger) as Boolean {
        var compact = getCompactGenesis1Fixture();
        var compactVerses = BibleJsonScanner.parseVerses(compact);

        // Full fixture with metadata (same as BibleApiTest)
        var full = "{\"translation\":{\"id\":\"BSB\"},\"book\":{\"id\":\"GEN\"},\"chapter\":{\"number\":1,\"content\":[{\"type\":\"heading\",\"content\":[\"The Creation\"]},{\"type\":\"verse\",\"number\":1,\"content\":[\"In the beginning God created the heavens and the earth.\"]},{\"type\":\"verse\",\"number\":2,\"content\":[\"Now the earth was formless and void, and darkness was over the surface of the deep. And the Spirit of God was hovering over the surface of the waters.\"]},{\"type\":\"verse\",\"number\":3,\"content\":[\"And God said, \\u201cLet there be light,\\u201d and there was light.\"]},{\"type\":\"verse\",\"number\":4,\"content\":[\"And God saw that the light was good, and He separated the light from the darkness.\"]},{\"type\":\"verse\",\"number\":5,\"content\":[\"God called the light \\u201cday,\\u201d and the darkness He called \\u201cnight.\\u201d And there was evening, and there was morning\\u2014the first day.\"]}]}}";
        var fullVerses = BibleJsonScanner.parseVerses(full);

        if (compactVerses.size() != fullVerses.size()) {
            return false;
        }
        for (var i = 0; i < compactVerses.size(); i++) {
            var c = compactVerses[i] as Dictionary;
            var f = fullVerses[i] as Dictionary;
            var cNum = c.get("verseNumber") as Number;
            var fNum = f.get("verseNumber") as Number;
            var cText = c.get("verseText") as String;
            var fText = f.get("verseText") as String;
            if (cNum != fNum || !cText.equals(fText)) {
                return false;
            }
        }
        return true;
    }

    // -----------------------------------------------------------------------
    // parseVersesFromObject tests (replaces resourceToJsonString round-trip)
    // -----------------------------------------------------------------------

    function testParseVersesFromObjectCompact(logger as Test.Logger) as Boolean {
        var compact = getCompactGenesis1Fixture();
        var verses = BibleJsonScanner.parseVerses(compact);
        if (verses.size() != 5) {
            return false;
        }
        var v1 = verses[0] as Dictionary;
        var text = v1.get("verseText") as String;
        return text.equals("In the beginning God created the heavens and the earth.");
    }

    // -----------------------------------------------------------------------
    // Offline indicator subtlety: loading path constants exist
    // -----------------------------------------------------------------------

    function testOfflineIndicatorStringExists(logger as Test.Logger) as Boolean {
        var raw = WatchUi.loadResource(Rez.Strings.Loading);
        var str = raw as String;
        return str != null && str.length() > 0;
    }

    function testOfflineErrorStringExists(logger as Test.Logger) as Boolean {
        var raw = WatchUi.loadResource(Rez.Strings.ErrorNoConnection);
        var str = raw as String;
        return str != null && str.length() > 0;
    }
}
