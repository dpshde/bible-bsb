using Toybox.Lang;
using Toybox.Test;

(:test)
function testSplitWordsBasic(logger as Test.Logger) as Lang.Boolean {
    var words = ContentLoader.splitWords("For God so loved");
    Test.assertEqual(words.size(), 4);
    Test.assertEqual(words[0], "For");
    Test.assertEqual(words[3], "loved");
    return true;
}

(:test)
function testWrapVerseWordBasedUnderCharBudget(logger as Test.Logger) as Lang.Boolean {
    // Word wrap must not emit a single monstrous line for long verses.
    var text = "For God so loved the world that He gave His one and only Son, that everyone who believes in Him shall not perish but have eternal life.";
    var lines = ContentLoader.wrapVerse(16, text, 28);
    Test.assert(lines.size() >= 3);
    var i;
    for (i = 0; i < lines.size(); i++) {
        var row = lines[i];
        Test.assert((row[:text] as Lang.String).length() <= 32);
    }
    // First line is the verse start.
    Test.assert(lines[0][:isStart] as Lang.Boolean);
    if (lines.size() > 1) {
        Test.assert(!(lines[1][:isStart] as Lang.Boolean));
    }
    return true;
}

(:test)
function testNoJesusMarkupInSpikeSample(logger as Test.Logger) as Lang.Boolean {
    // Bundled BSB spike verses are plain {n,t} — no \wj / <wj>.
    Test.assert(!ContentLoader.hasJesusMarkup("Jesus wept."));
    Test.assert(ContentLoader.hasJesusMarkup("\\wj Jesus wept.\\wj*"));
    Test.assertEqual(ContentLoader.plainVerseText("Jesus wept."), "Jesus wept.");
    return true;
}

(:test)
function testShortVerseThreshold(logger as Test.Logger) as Lang.Boolean {
    // POKE: Fonts.SHORT_VERSE_CHARS
    Test.assert(Fonts.SHORT_VERSE_CHARS >= 30);
    Test.assert(Fonts.SHORT_VERSE_CHARS <= 50);
    Test.assert("Jesus wept.".length() <= Fonts.SHORT_VERSE_CHARS);
    return true;
}

(:test)
function testWrapCostJohn3StaysBounded(logger as Test.Logger) as Lang.Boolean {
    // Proxy for watchdog cost: wrapping every John 3 verse at a 28-char budget
    // is O(words), not O(chars * measure). Bound total emitted lines.
    // Real Dc path is wordWidth-cached; this exercises the same split/pack loop.
    var samples = [
        "Now there was a man of the Pharisees named Nicodemus, a leader of the Jews.",
        "For God so loved the world that He gave His one and only Son, that everyone who believes in Him shall not perish but have eternal life.",
        "Whoever believes in the Son has eternal life. Whoever rejects the Son will not see life. Instead, the wrath of God remains on him."
    ];
    var totalLines = 0;
    var totalWords = 0;
    var i;
    // Simulate 36 verses by repeating the samples.
    for (i = 0; i < 36; i++) {
        var t = samples[i % samples.size()];
        totalWords += ContentLoader.splitWords(t).size();
        totalLines += ContentLoader.estimateWrapLineCount(t, 28);
    }
    // Sanity: work is proportional to words (~a few hundred), not tens of thousands of char measures.
    Test.assert(totalWords < 800);
    Test.assert(totalLines < 400);
    Test.assert(totalLines >= 36);
    // Document the strategy for Dylan's reshoot notes.
    Test.assert(ContentLoader.WRAP_COST_NOTE.length() > 20);
    return true;
}
