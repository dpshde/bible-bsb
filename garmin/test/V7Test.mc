using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Test;

//! v7: "Vibrate on scroll" defaults on, persists, and survives a corrupt value.
(:test)
function testScrollVibeSettingPersists(logger as Test.Logger) as Lang.Boolean {
    Application.Storage.deleteValue(Feedback.STEP_KEY);
    Feedback.refresh();
    Test.assert(Feedback.stepEnabled());            // default on
    NativeLists.applySetting(:vibeScroll, false);
    Test.assert(!Feedback.stepEnabled());           // stored
    Test.assert(Application.Storage.getValue(Feedback.STEP_KEY) == false);
    Feedback.step();                                // off: must be a silent no-op
    Application.Storage.setValue(Feedback.STEP_KEY, 7);
    Test.assert(Feedback.stepEnabled());            // corrupt -> default
    Application.Storage.deleteValue(Feedback.STEP_KEY);
    Feedback.refresh();
    return true;
}

//! Go to's first step is the chapter grid in letter mode: 17 letters + "1–3".
(:test)
function testGoToLetterGrid(logger as Test.Logger) as Lang.Boolean {
    GoTo.letterFocus = 4; // "G"
    var v = new ChapterGridView();
    v.setLetterMode();
    Test.assertEqual(v.mode, GRID_LETTERS);
    Test.assertEqual(v.grid.itemCount, 18); // 17 letters + "1–3"
    Test.assertEqual(v.grid.focusIndex, 4);
    Test.assertEqual(v._gridBook, -1);
    Test.assert((GoTo.letters()[4] as Lang.String).equals("G"));
    Test.assert((GoTo.letters()[17] as Lang.String).equals(GoTo.DIGITS));
    GoTo.letterFocus = 0;
    return true;
}

(:test)
function testGoToLetterSummaries(logger as Test.Logger) as Lang.Boolean {
    Test.assert(GoTo.letterSummary(4).equals("Genesis, Galatians"));  // G
    Test.assert(GoTo.letterSummary(0).equals("Amos, Acts"));          // A (canonical order)
    Test.assert(GoTo.letterSummary(17).equals("17 books"));           // 1–3
    return true;
}

//! v7: the "Hold UP for menu" footer goes away once the menu was opened that way.
(:test)
function testMenuHintSeen(logger as Test.Logger) as Lang.Boolean {
    Application.Storage.deleteValue(MenuHint.SEEN_KEY);
    MenuHint._seen = null;
    Test.assert(!MenuHint.seen());
    MenuHint.markSeen();
    Test.assert(MenuHint.seen());
    MenuHint._seen = null;
    Test.assert(MenuHint.seen()); // persisted
    Application.Storage.deleteValue(MenuHint.SEEN_KEY);
    MenuHint._seen = null;
    return true;
}

//! v8: reader verse text is the heavy face, reader headings + reference line the light face;
//! titles and the chapter divider keep the heavy heading face. One face per role (focus = dimming).
(:test)
function testFacesRoles(logger as Test.Logger) as Lang.Boolean {
    var body = Faces.body();
    var head = Faces.head(Graphics.FONT_XTINY);
    var light = Faces.light(Graphics.FONT_XTINY);
    Test.assert(body != null && head != null && light != null);
    if (SysWeight.BOLD) {
        Test.assert(body == Graphics.FONT_XTINY);         // bold system font for verses
        Test.assert(head == Graphics.FONT_XTINY);         // bold titles / divider
        if (Graphics has :getVectorFont) {
            Test.assert(!(light instanceof Lang.Number)); // regular built-in face for headings + ref
        }
    } else {
        Test.assert(light == Graphics.FONT_XTINY);        // system (regular) font for headings + ref
    }
    Test.assert(Faces.body() == body);                   // cached, stable
    Test.assert(Faces.light(Graphics.FONT_XTINY) == light);
    return true;
}

//! Dylan 2026-11-03: a bookmark's snippet is the verse itself, without the psalm superscription.
(:test)
function testSnippetSkipsPsalmTitle(logger as Test.Logger) as Lang.Boolean {
    Snippets._cache = {};
    var s23 = Snippets.make(Bookmarks.pack(18, 23, 1));
    Test.assert(s23 != null && (s23 as Lang.String).find("The LORD is my") == 0);
    var s9 = Snippets.make(Bookmarks.pack(18, 9, 1)); // title has curly quotes
    Test.assert(s9 != null && (s9 as Lang.String).find("I will give thanks") == 0);
    var s18 = Snippets.make(Bookmarks.pack(18, 18, 1)); // long title ending "He said:"
    Test.assert(s18 != null && (s18 as Lang.String).find("I love You") == 0);
    var s1 = Snippets.make(Bookmarks.pack(18, 1, 1)); // no title: unchanged
    Test.assert(s1 != null && (s1 as Lang.String).find("Blessed is the man") == 0);
    var j = Snippets.make(Bookmarks.pack(42, 11, 35));
    Test.assert(j != null && (j as Lang.String).equals("Jesus wept."));
    return true;
}

//! Genre spans and names match Hidden Word (public/groups.js GENRES).
(:test)
function testBookmarkGenres(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(Genres.ofBook(0), 0);   // Genesis: Law
    Test.assertEqual(Genres.ofBook(16), 1);  // Esther: History
    Test.assertEqual(Genres.ofBook(18), 2);  // Psalms: Wisdom & Poetry
    Test.assertEqual(Genres.ofBook(43), 6);  // Acts
    Test.assertEqual(Genres.ofBook(56), 7);  // Philemon: Pauline Letters
    Test.assertEqual(Genres.ofBook(64), 8);  // Jude: General Letters
    Test.assertEqual(Genres.ofBook(65), 9);  // Revelation
    Test.assert((Genres.HW_NAMES[2] as Lang.String).equals("Wisdom & Poetry"));
    var c = NativeLists.genreCounts([Bookmarks.pack(18, 23, 1), Bookmarks.pack(18, 1, 1), Bookmarks.pack(42, 11, 35)]);
    Test.assertEqual(c[2], 2);
    Test.assertEqual(c[5], 1);
    Test.assertEqual(c[0], 0);
    return true;
}
