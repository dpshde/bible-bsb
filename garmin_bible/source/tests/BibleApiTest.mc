import Toybox.Lang;
using Toybox.Test;

class BibleApiTest {

    // -----------------------------------------------------------------------
    // Fixture JSON helpers (embedded since file I/O is limited in tests)
    // -----------------------------------------------------------------------

    private function getGenesis1Fixture() as String {
        return "{\"translation\":{\"id\":\"BSB\",\"name\":\"Berean Standard Bible\"},\"book\":{\"id\":\"GEN\",\"name\":\"Genesis\",\"osisId\":\"Gen\"},\"numberOfVerses\":5,\"chapter\":{\"number\":1,\"content\":[{\"type\":\"heading\",\"content\":[\"The Creation\"]},{\"type\":\"verse\",\"number\":1,\"content\":[\"In the beginning God created the heavens and the earth.\"]},{\"type\":\"verse\",\"number\":2,\"content\":[\"And the earth was formless and void, and darkness was over the surface of the deep.\"]},{\"type\":\"verse\",\"number\":3,\"content\":[\"Then God said, 'Let there be light,' and there was light.\"]},{\"type\":\"line_break\"},{\"type\":\"verse\",\"number\":4,\"content\":[\"And God saw that the light was good. \",{\"text\":\"And He separated the light from the darkness.\"}]},{\"type\":\"verse\",\"number\":5,\"content\":[\"God called the light 'day,' and the darkness He called 'night.'\",{\"noteId\":0}]}],\"footnotes\":[{\"noteId\":0,\"text\":\"Or evening\",\"caller\":\"+\",\"reference\":{\"chapter\":1,\"verse\":5}}]}}";
    }

    private function getJohn3Fixture() as String {
        return "{\"translation\":{\"id\":\"BSB\",\"name\":\"Berean Standard Bible\"},\"book\":{\"id\":\"JHN\",\"name\":\"John\",\"osisId\":\"John\"},\"numberOfVerses\":4,\"chapter\":{\"number\":3,\"content\":[{\"type\":\"heading\",\"content\":[\"Jesus and Nicodemus\"]},{\"type\":\"verse\",\"number\":1,\"content\":[\"Now there was a man of the Pharisees named Nicodemus, a member of the Jewish ruling council.\"]},{\"type\":\"verse\",\"number\":2,\"content\":[\"He came to Jesus at night and said, 'Rabbi, we know that You are a teacher who has come from God. '\",{\"text\":\"For no one could perform the signs You are doing if God were not with him.\",\"wordsOfJesus\":true}]},{\"type\":\"verse\",\"number\":3,\"content\":[\"Jesus replied, 'Truly, truly, I tell you, no one can see the kingdom of God unless he is born again.'\",{\"text\":\"\",\"wordsOfJesus\":true}]},{\"type\":\"verse\",\"number\":4,\"content\":[\"'How can a man be born when he is old?' Nicodemus asked. '\",{\"text\":\"Surely he cannot enter a second time into his mother's womb to be born!\"}]}],\"footnotes\":[]}}";
    }

    private function getPsalm23Fixture() as String {
        return "{\"translation\":{\"id\":\"BSB\",\"name\":\"Berean Standard Bible\"},\"book\":{\"id\":\"PSA\",\"name\":\"Psalms\",\"osisId\":\"Ps\"},\"numberOfVerses\":6,\"chapter\":{\"number\":23,\"content\":[{\"type\":\"verse\",\"number\":1,\"content\":[{\"text\":\"The LORD is my shepherd;\",\"poem\":1},{\"text\":\"I shall not want.\",\"poem\":2}]},{\"type\":\"verse\",\"number\":2,\"content\":[{\"text\":\"He makes me lie down in green pastures.\",\"poem\":1},{\"text\":\"He leads me beside quiet waters.\",\"poem\":2}]},{\"type\":\"verse\",\"number\":3,\"content\":[{\"text\":\"He restores my soul;\",\"poem\":1},{\"text\":\"He guides me in the paths of righteousness\",\"poem\":2},{\"text\":\"for the sake of His name.\",\"poem\":3}]},{\"type\":\"verse\",\"number\":4,\"content\":[{\"text\":\"Even though I walk through the valley of the shadow of death,\",\"poem\":1},{\"text\":\"I will fear no evil,\",\"poem\":2},{\"text\":\"for You are with me;\",\"poem\":3},{\"text\":\"Your rod and Your staff, they comfort me.\",\"poem\":4}]},{\"type\":\"verse\",\"number\":5,\"content\":[{\"text\":\"You prepare a table before me\",\"poem\":1},{\"text\":\"in the presence of my enemies.\",\"poem\":2},{\"text\":\"You anoint my head with oil;\",\"poem\":3},{\"text\":\"my cup overflows.\",\"poem\":4}]},{\"type\":\"verse\",\"number\":6,\"content\":[{\"text\":\"Surely goodness and mercy will follow me\",\"poem\":1},{\"text\":\"all the days of my life,\",\"poem\":2},{\"text\":\"and I will dwell in the house of the LORD\",\"poem\":3},{\"text\":\"forever.\",\"poem\":4}]}],\"footnotes\":[]}}";
    }

    private function getPsalm119Fixture() as String {
        return "{\"translation\":{\"id\":\"BSB\",\"name\":\"Berean Standard Bible\"},\"book\":{\"id\":\"PSA\",\"name\":\"Psalms\",\"osisId\":\"Ps\"},\"numberOfVerses\":176,\"chapter\":{\"number\":119,\"content\":[{\"type\":\"heading\",\"content\":[\"Aleph\"]},{\"type\":\"verse\",\"number\":1,\"content\":[{\"text\":\"Blessed are those whose way is blameless,\",\"poem\":1},{\"text\":\"who walk in the law of the LORD.\",\"poem\":2}]},{\"type\":\"verse\",\"number\":2,\"content\":[{\"text\":\"Blessed are those who keep His testimonies\",\"poem\":1},{\"text\":\"and seek Him with all their heart.\",\"poem\":2}]},{\"type\":\"verse\",\"number\":3,\"content\":[{\"text\":\"They do no iniquity;\",\"poem\":1},{\"text\":\"they walk in His ways.\",\"poem\":2}]},{\"type\":\"verse\",\"number\":176,\"content\":[{\"text\":\"I have gone astray like a lost sheep;\",\"poem\":1},{\"text\":\"seek Your servant,\",\"poem\":2},{\"text\":\"for I do not forget Your commandments.\",\"poem\":3}]}],\"footnotes\":[]}}";
    }

    // -----------------------------------------------------------------------
    // URL construction tests
    // -----------------------------------------------------------------------

    function testBuildUrlGenesis1(logger as Test.Logger) as Boolean {
        var url = BibleApi.buildUrl(0, 1);
        return url.equals("https://bible.helloao.org/api/BSB/gen/1.json");
    }

    function testBuildUrl1Samuel1(logger as Test.Logger) as Boolean {
        var url = BibleApi.buildUrl(8, 1);
        return url.equals("https://bible.helloao.org/api/BSB/1sa/1.json");
    }

    function testBuildUrlPsalms23(logger as Test.Logger) as Boolean {
        var url = BibleApi.buildUrl(18, 23);
        return url.equals("https://bible.helloao.org/api/BSB/psa/23.json");
    }

    function testBuildUrlRevelation22(logger as Test.Logger) as Boolean {
        var url = BibleApi.buildUrl(65, 22);
        return url.equals("https://bible.helloao.org/api/BSB/rev/22.json");
    }

    function testBuildUrlAll66Books(logger as Test.Logger) as Boolean {
        for (var i = 0; i < BibleBooks.BOOK_COUNT; i++) {
            var osis = BibleBooks.getOsisCode(i);
            if (osis == null) {
                return false;
            }
            var url = BibleApi.buildUrl(i, 1);
            var expectedPrefix = "https://bible.helloao.org/api/BSB/" + osis + "/";
            var prefix = url.substring(0, expectedPrefix.length());
            if (prefix == null || !prefix.equals(expectedPrefix)) {
                return false;
            }
        }
        return true;
    }

    // -----------------------------------------------------------------------
    // JSON parsing tests — Genesis 1 fixture
    // -----------------------------------------------------------------------

    function testParseGenesis1VerseCount(logger as Test.Logger) as Boolean {
        var json = getGenesis1Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        return verses.size() == 5;
    }

    function testParseGenesis1Verse1Text(logger as Test.Logger) as Boolean {
        var json = getGenesis1Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        if (verses.size() < 1) {
            return false;
        }
        var v = verses[0] as Dictionary;
        var text = v.get("verseText") as String;
        return text.equals("In the beginning God created the heavens and the earth.");
    }

    function testParseGenesis1Verse1Number(logger as Test.Logger) as Boolean {
        var json = getGenesis1Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        if (verses.size() < 1) {
            return false;
        }
        var v = verses[0] as Dictionary;
        var num = v.get("verseNumber") as Number;
        return num == 1;
    }

    function testParseGenesis1Verse4FormattedText(logger as Test.Logger) as Boolean {
        var json = getGenesis1Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        if (verses.size() < 4) {
            return false;
        }
        var v = verses[3] as Dictionary;
        var text = v.get("verseText") as String;
        return text.equals("And God saw that the light was good. And He separated the light from the darkness.");
    }

    function testParseGenesis1FootnoteStripped(logger as Test.Logger) as Boolean {
        var json = getGenesis1Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        if (verses.size() < 5) {
            return false;
        }
        var v = verses[4] as Dictionary;
        var text = v.get("verseText") as String;
        return text.equals("God called the light 'day,' and the darkness He called 'night.'");
    }

    function testParseGenesis1HeadingSkipped(logger as Test.Logger) as Boolean {
        var json = getGenesis1Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        // "The Creation" heading should not appear as a verse
        if (verses.size() < 1) {
            return false;
        }
        var v = verses[0] as Dictionary;
        var text = v.get("verseText") as String;
        return !text.equals("The Creation");
    }

    // -----------------------------------------------------------------------
    // JSON parsing tests — John 3 fixture (wordsOfJesus)
    // -----------------------------------------------------------------------

    function testParseJohn3VerseCount(logger as Test.Logger) as Boolean {
        var json = getJohn3Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        return verses.size() == 4;
    }

    function testParseJohn3Verse2WordsOfJesus(logger as Test.Logger) as Boolean {
        var json = getJohn3Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        if (verses.size() < 2) {
            return false;
        }
        var v = verses[1] as Dictionary;
        var text = v.get("verseText") as String;
        return text.find("For no one could perform the signs You are doing if God were not with him.") != null;
    }

    function testParseJohn3Verse3EmptyWordsOfJesus(logger as Test.Logger) as Boolean {
        var json = getJohn3Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        if (verses.size() < 3) {
            return false;
        }
        var v = verses[2] as Dictionary;
        var text = v.get("verseText") as String;
        // Empty wordsOfJesus text should be skipped; the verse still has the main string
        return text.find("Truly, truly, I tell you") != null;
    }

    // -----------------------------------------------------------------------
    // JSON parsing tests — Psalm 23 fixture (poem formatting)
    // -----------------------------------------------------------------------

    function testParsePsalm23VerseCount(logger as Test.Logger) as Boolean {
        var json = getPsalm23Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        return verses.size() == 6;
    }

    function testParsePsalm23Verse1Text(logger as Test.Logger) as Boolean {
        var json = getPsalm23Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        if (verses.size() < 1) {
            return false;
        }
        var v = verses[0] as Dictionary;
        var text = v.get("verseText") as String;
        return text.equals("The LORD is my shepherd; I shall not want.");
    }

    function testParsePsalm23Verse6Text(logger as Test.Logger) as Boolean {
        var json = getPsalm23Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        if (verses.size() < 6) {
            return false;
        }
        var v = verses[5] as Dictionary;
        var text = v.get("verseText") as String;
        return text.equals("Surely goodness and mercy will follow me all the days of my life, and I will dwell in the house of the LORD forever.");
    }

    // -----------------------------------------------------------------------
    // JSON parsing tests — Psalm 119 fixture (large chapter)
    // -----------------------------------------------------------------------

    function testParsePsalm119VerseCount(logger as Test.Logger) as Boolean {
        var json = getPsalm119Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        return verses.size() == 4; // fixture only has 4 verses
    }

    function testParsePsalm119Verse1Text(logger as Test.Logger) as Boolean {
        var json = getPsalm119Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        if (verses.size() < 1) {
            return false;
        }
        var v = verses[0] as Dictionary;
        var text = v.get("verseText") as String;
        return text.equals("Blessed are those whose way is blameless, who walk in the law of the LORD.");
    }

    function testParsePsalm119Verse176Text(logger as Test.Logger) as Boolean {
        var json = getPsalm119Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        if (verses.size() < 4) {
            return false;
        }
        var v = verses[3] as Dictionary;
        var num = v.get("verseNumber") as Number;
        var text = v.get("verseText") as String;
        return num == 176 && text.equals("I have gone astray like a lost sheep; seek Your servant, for I do not forget Your commandments.");
    }

    function testParsePsalm119HeadingSkipped(logger as Test.Logger) as Boolean {
        var json = getPsalm119Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        if (verses.size() < 1) {
            return false;
        }
        var v = verses[0] as Dictionary;
        var num = v.get("verseNumber") as Number;
        // "Aleph" heading should be skipped, first verse should be number 1
        return num == 1;
    }

    // -----------------------------------------------------------------------
    // Malformed JSON tests
    // -----------------------------------------------------------------------

    function testParseTruncatedJson(logger as Test.Logger) as Boolean {
        var json = "{\"translation\":{\"id\":\"BSB\",\"name\"";
        var verses = BibleJsonScanner.parseVerses(json);
        return verses.size() == 0;
    }

    function testParseMissingType(logger as Test.Logger) as Boolean {
        var json = "{\"chapter\":{\"content\":[{\"number\":1,\"content\":[\"Missing type field\"]}]}}";
        var verses = BibleJsonScanner.parseVerses(json);
        return verses.size() == 0;
    }

    function testParseWrongTypes(logger as Test.Logger) as Boolean {
        var json = "{\"chapter\":{\"content\":[{\"type\":123,\"number\":\"one\",\"content\":\"not an array\"}]}}";
        var verses = BibleJsonScanner.parseVerses(json);
        return verses.size() == 0;
    }

    function testParseEmptyString(logger as Test.Logger) as Boolean {
        var verses = BibleJsonScanner.parseVerses("");
        return verses.size() == 0;
    }

    function testParseNoContentKey(logger as Test.Logger) as Boolean {
        var json = "{\"translation\":{\"id\":\"BSB\"},\"book\":{\"id\":\"GEN\"}}";
        var verses = BibleJsonScanner.parseVerses(json);
        return verses.size() == 0;
    }

    // -----------------------------------------------------------------------
    // parseResponse wrapper tests
    // -----------------------------------------------------------------------

    function testParseResponseWithNull(logger as Test.Logger) as Boolean {
        var verses = BibleApi.parseResponse(null);
        return verses.size() == 0;
    }

    function testParseResponseWithEmptyString(logger as Test.Logger) as Boolean {
        var verses = BibleApi.parseResponse("");
        return verses.size() == 0;
    }

    function testParseResponseWithDictionary(logger as Test.Logger) as Boolean {
        var dict = {} as Dictionary;
        var verses = BibleApi.parseResponse(dict);
        return verses.size() == 0;
    }

    // -----------------------------------------------------------------------
    // Error message tests
    // -----------------------------------------------------------------------

    function testErrorMessage404(logger as Test.Logger) as Boolean {
        var msg = BibleApi.getErrorMessage(404);
        return msg.equals("Chapter not found");
    }

    function testErrorMessageNoConnection(logger as Test.Logger) as Boolean {
        var msg = BibleApi.getErrorMessage(-1);
        return msg.equals("No connection");
    }

    function testErrorMessageNegativeCode(logger as Test.Logger) as Boolean {
        var msg = BibleApi.getErrorMessage(-104);
        return msg.equals("No connection");
    }

    function testErrorMessage500(logger as Test.Logger) as Boolean {
        var msg = BibleApi.getErrorMessage(500);
        return msg.equals("Failed to load chapter");
    }

    function testErrorMessage502(logger as Test.Logger) as Boolean {
        var msg = BibleApi.getErrorMessage(502);
        return msg.equals("Failed to load chapter");
    }

    // -----------------------------------------------------------------------
    // Verse ordering tests
    // -----------------------------------------------------------------------

    function testVerseNumbersAreSequential(logger as Test.Logger) as Boolean {
        var json = getPsalm23Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        for (var i = 0; i < verses.size(); i++) {
            var v = verses[i] as Dictionary;
            var num = v.get("verseNumber") as Number;
            if (num != i + 1) {
                return false;
            }
        }
        return true;
    }

    // -----------------------------------------------------------------------
    // Memory-safety smoke: large chapter does not crash scanner
    // -----------------------------------------------------------------------

    function testLargeChapterDoesNotCrash(logger as Test.Logger) as Boolean {
        var json = getPsalm119Fixture();
        var verses = BibleJsonScanner.parseVerses(json);
        // Fixture has 4 verses; on a real 176-verse response the scanner
        // would process them incrementally without large pre-allocation.
        return verses.size() > 0;
    }

    // -----------------------------------------------------------------------
    // Fix 4: BibleJsonScanner.parseVersesFromObject — direct Dictionary parsing
    // -----------------------------------------------------------------------

    private function getGenesis1Dictionary() as Dictionary {
        // Build the nested Dictionary structure that Application.loadResource returns
        var v1 = { "type" => "verse", "number" => 1, "content" => ["In the beginning God created the heavens and the earth."] } as Dictionary;
        var v2 = { "type" => "verse", "number" => 2, "content" => ["And the earth was formless and void."] } as Dictionary;
        var heading = { "type" => "heading", "content" => ["The Creation"] } as Dictionary;
        var chapter = { "content" => [heading, v1, v2] } as Dictionary;
        return { "chapter" => chapter } as Dictionary;
    }

    private function getPsalm23Dictionary() as Dictionary {
        var v1 = { "type" => "verse", "number" => 1, "content" => [
            { "text" => "The LORD is my shepherd;", "poem" => 1 },
            { "text" => "I shall not want.", "poem" => 2 }
        ] } as Dictionary;
        var v2 = { "type" => "verse", "number" => 2, "content" => [
            { "text" => "He makes me lie down in green pastures.", "poem" => 1 },
            { "text" => "He leads me beside quiet waters.", "poem" => 2 }
        ] } as Dictionary;
        var chapter = { "content" => [v1, v2] } as Dictionary;
        return { "chapter" => chapter } as Dictionary;
    }

    private function getGenesis1WithNoteDictionary() as Dictionary {
        var v1 = { "type" => "verse", "number" => 5, "content" => [
            "God called the light 'day,' and the darkness He called 'night.'",
            { "noteId" => 0, "text" => "Or evening" }
        ] } as Dictionary;
        var chapter = { "content" => [v1] } as Dictionary;
        return { "chapter" => chapter } as Dictionary;
    }

    function testParseVersesFromObjectGenesis1(logger as Test.Logger) as Boolean {
        var dict = getGenesis1Dictionary();
        var verses = BibleJsonScanner.parseVersesFromObject(dict);
        return verses.size() == 2;
    }

    function testParseVersesFromObjectVerse1Text(logger as Test.Logger) as Boolean {
        var dict = getGenesis1Dictionary();
        var verses = BibleJsonScanner.parseVersesFromObject(dict);
        if (verses.size() < 1) {
            return false;
        }
        var v = verses[0] as Dictionary;
        var text = v.get("verseText") as String;
        return text.equals("In the beginning God created the heavens and the earth.");
    }

    function testParseVersesFromObjectHeadingSkipped(logger as Test.Logger) as Boolean {
        var dict = getGenesis1Dictionary();
        var verses = BibleJsonScanner.parseVersesFromObject(dict);
        if (verses.size() < 1) {
            return false;
        }
        var v = verses[0] as Dictionary;
        var text = v.get("verseText") as String;
        return !text.equals("The Creation");
    }

    function testParseVersesFromObjectPsalm23(logger as Test.Logger) as Boolean {
        var dict = getPsalm23Dictionary();
        var verses = BibleJsonScanner.parseVersesFromObject(dict);
        if (verses.size() < 1) {
            return false;
        }
        var v = verses[0] as Dictionary;
        var text = v.get("verseText") as String;
        return text.equals("The LORD is my shepherd; I shall not want.");
    }

    function testParseVersesFromObjectFootnoteStripped(logger as Test.Logger) as Boolean {
        var dict = getGenesis1WithNoteDictionary();
        var verses = BibleJsonScanner.parseVersesFromObject(dict);
        if (verses.size() < 1) {
            return false;
        }
        var v = verses[0] as Dictionary;
        var text = v.get("verseText") as String;
        return text.equals("God called the light 'day,' and the darkness He called 'night.'");
    }

    function testParseVersesFromObjectEmptyDict(logger as Test.Logger) as Boolean {
        var dict = {} as Dictionary;
        var verses = BibleJsonScanner.parseVersesFromObject(dict);
        return verses.size() == 0;
    }

    function testParseVersesFromObjectNullChapter(logger as Test.Logger) as Boolean {
        var dict = { "other" => "data" } as Dictionary;
        var verses = BibleJsonScanner.parseVersesFromObject(dict);
        return verses.size() == 0;
    }

    function testParseVersesFromObjectDirectContent(logger as Test.Logger) as Boolean {
        // Some resources might store content array directly at root
        var v1 = { "type" => "verse", "number" => 1, "content" => ["Hello world."] } as Dictionary;
        var dict = { "content" => [v1] } as Dictionary;
        var verses = BibleJsonScanner.parseVersesFromObject(dict);
        return verses.size() == 1;
    }

    function testParseVersesFromObjectNumericBooksNotInResource(logger as Test.Logger) as Boolean {
        // loadFromResource should return empty for a non-existent resource
        var verses = BibleApi.loadFromResource(7, 1); // Judges has no resource
        return verses.size() == 0;
    }
}
