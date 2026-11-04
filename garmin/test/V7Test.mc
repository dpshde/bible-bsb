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

//! v7: Filter by letter is the chapter grid in filter mode (22 cells, Flipper order).
(:test)
function testFilterGridMode(logger as Test.Logger) as Lang.Boolean {
    NativeLists.filterFocus = 4; // "E"
    var v = new ChapterGridView();
    v.setFilterMode();
    Test.assertEqual(v.mode, GRID_FILTER);
    Test.assertEqual(v.grid.itemCount, 22);
    Test.assertEqual(v.grid.focusIndex, 4);
    Test.assertEqual(v._gridBook, -1);
    NativeLists.filterFocus = 0;
    return true;
}

(:test)
function testFilterSummaries(logger as Test.Logger) as Lang.Boolean {
    Test.assert(NativeLists.filterSummary(0).equals("All 66 books"));
    Test.assert(NativeLists.filterSummary(3).equals("Deuteronomy, Daniel")); // "D"
    Test.assert(NativeLists.filterSummary(9).equals("No books"));            // "K": all numbered
    Test.assert(NativeLists.filterSummary(19).equals("17 books"));           // "1" = every numbered book
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
