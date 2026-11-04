using Toybox.Lang;
using Toybox.Test;

//! FULL OFFLINE (HOLY_BIBLE_GAPS item 0): first + last chapter of all 66 books load
//! from bundled resources only (app declares no permissions; no Communications).
(:test)
function testOfflineFirstLastAll66(logger as Test.Logger) as Lang.Boolean {
    var fails = 0;
    var b;
    for (b = 0; b < Books.BOOK_COUNT; b++) {
        var last = Books.chapterCount(b);
        var f = ContentLoader.loadChapter(b, 1);
        var l = ContentLoader.loadChapter(b, last);
        var fv = f == null ? 0 : (f[:verses] as Lang.Array).size();
        var lv = l == null ? 0 : (l[:verses] as Lang.Array).size();
        var beyond = BsbIndex.rez(b, last + 1) == null;
        var ok = fv > 0 && lv > 0 && beyond;
        if (!ok) {
            fails++;
        }
        logger.debug("OFFLINE " + Books.osis(b) + " 1:" + fv + "v " + last + ":" + lv + "v " + (ok ? "PASS" : "FAIL"));
    }
    logger.debug("OFFLINE fails=" + fails);
    return fails == 0;
}
