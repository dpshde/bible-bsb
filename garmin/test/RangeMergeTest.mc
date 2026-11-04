using Toybox.Application;
using Toybox.Lang;
using Toybox.Test;

//! Dylan 2026-11-03: Bookmarks rows merge consecutive same-book, same-chapter, same-color verses
//! at display time (Bookmarks.mergeRows); storage stays one id per verse.
module RmT {
    function ps(c as Lang.Number, v as Lang.Number) as Lang.Number { return Bookmarks.pack(18, c, v); }
}

(:test)
function testMergeConsecutiveSameColor(logger as Test.Logger) as Lang.Boolean {
    var ids = [RmT.ps(23, 3), RmT.ps(23, 1), RmT.ps(23, 4), RmT.ps(23, 2)];
    var col = {RmT.ps(23, 1) => "yellow", RmT.ps(23, 2) => "yellow", RmT.ps(23, 3) => "yellow", RmT.ps(23, 4) => "yellow"};
    var rows = Bookmarks.mergeRows(ids, col, 100);
    Test.assertEqual(rows.size(), 1);
    Test.assertEqual(rows[0], Bookmarks.packRange(18, 23, 1, 4));
    Test.assertEqual(Bookmarks.formatLabel(rows[0] as Lang.Number), "Psalms 23:1–4");
    Test.assertEqual(Bookmarks.mergeRows(ids, null, 100).size(), 1); // no colors: adjacency only
    return true;
}

(:test)
function testMergeGapSplits(logger as Test.Logger) as Lang.Boolean {
    var rows = Bookmarks.mergeRows([RmT.ps(23, 1), RmT.ps(23, 2), RmT.ps(23, 4)], null, 100);
    Test.assertEqual(rows.size(), 2);
    Test.assertEqual(rows[0], Bookmarks.packRange(18, 23, 1, 2));
    Test.assertEqual(rows[1], RmT.ps(23, 4));
    return true;
}

(:test)
function testMergeColorChangeSplits(logger as Test.Logger) as Lang.Boolean {
    var ids = [RmT.ps(23, 1), RmT.ps(23, 2), RmT.ps(23, 3)];
    var rows = Bookmarks.mergeRows(ids, {RmT.ps(23, 1) => "yellow", RmT.ps(23, 2) => "yellow", RmT.ps(23, 3) => "blue"}, 100);
    Test.assertEqual(rows.size(), 2);
    Test.assertEqual(rows[0], Bookmarks.packRange(18, 23, 1, 2));
    Test.assertEqual(rows[1], RmT.ps(23, 3));
    // an uncolored verse doesn't join a colored one
    rows = Bookmarks.mergeRows(ids, {RmT.ps(23, 1) => "yellow", RmT.ps(23, 3) => "yellow"}, 100);
    Test.assertEqual(rows.size(), 3);
    return true;
}

(:test)
function testMergeChapterAndBookBoundary(logger as Test.Logger) as Lang.Boolean {
    var rows = Bookmarks.mergeRows([RmT.ps(23, 6), RmT.ps(24, 1), Bookmarks.pack(19, 23, 7)], null, 100);
    Test.assertEqual(rows.size(), 3);
    // chapter bookmarks stay their own row; legacy stored ranges expand and merge with neighbors
    rows = Bookmarks.mergeRows([Bookmarks.pack(18, 23, 0), Bookmarks.packRange(18, 23, 1, 3), RmT.ps(23, 4)], null, 100);
    Test.assertEqual(rows.size(), 2);
    Test.assertEqual(rows[0], Bookmarks.pack(18, 23, 0));
    Test.assertEqual(rows[1], Bookmarks.packRange(18, 23, 1, 4));
    Test.assertEqual(Bookmarks.verses([rows[1]]).size(), 4);
    Test.assertEqual(Bookmarks.mergeRows([RmT.ps(1, 1), RmT.ps(2, 1), RmT.ps(3, 1)], null, 2).size(), 2); // max
    return true;
}

//! Multi-part verse: the whole-verse part's color, else the top part (largest edited, else created).
(:test)
function testMergeMultiPartVerseColor(logger as Test.Logger) as Lang.Boolean {
    var r = HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"PSA.23.2\",\"updated\":9,\"highlights\":[{\"color\":\"green\",\"created\":3},{\"color\":\"blue\",\"start\":4,\"end\":9,\"created\":8}]}") as HwObj;
    Test.assertEqual(HwMap.displayColor(r), "green"); // whole part wins over the newer partial
    Test.assertEqual(HwMap.topColor(r), "blue");
    var p = HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"PSA.23.2\",\"updated\":9,\"highlights\":[{\"color\":\"green\",\"start\":0,\"end\":3,\"created\":3,\"edited\":9},{\"color\":\"blue\",\"start\":4,\"end\":9,\"created\":8}]}") as HwObj;
    Test.assertEqual(HwMap.displayColor(p), "green"); // no whole part: top part (edited 9)
    Test.assert(HwMap.displayColor(HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"PSA.23.2\",\"deleted\":true}") as HwObj) == null);
    // So verse 2 (green by its whole part) splits a yellow 1..3 run.
    var rows = Bookmarks.mergeRows([RmT.ps(23, 1), RmT.ps(23, 2), RmT.ps(23, 3)],
        {RmT.ps(23, 1) => "yellow", RmT.ps(23, 2) => HwMap.displayColor(r), RmT.ps(23, 3) => "yellow"}, 100);
    Test.assertEqual(rows.size(), 3);
    return true;
}

//! Recolor rewrites one record: whole parts take the color, partial parts and unknown fields stay.
(:test)
function testRecolorKeepsPartsAndFields(logger as Test.Logger) as Lang.Boolean {
    var r = HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"PSA.23.2\",\"updated\":9,\"x-note\":\"keep\",\"highlights\":[{\"color\":\"green\",\"created\":3},{\"color\":\"blue\",\"start\":4,\"end\":9,\"quote\":\"still\",\"created\":8}]}") as HwObj;
    var o = HwMap.recolor(r, "PSA.23.2", "pink", 20l);
    var hs = o.get("highlights") as Lang.Array;
    Test.assertEqual(hs.size(), 2);
    Test.assertEqual((hs[0] as HwObj).get("color"), "pink");
    Test.assertEqual(HwMap.num((hs[0] as HwObj).get("edited")), 20l);
    Test.assertEqual((hs[1] as HwObj).get("color"), "blue");
    Test.assertEqual((hs[1] as HwObj).get("quote"), "still");
    Test.assertEqual(o.get("x-note"), "keep");
    Test.assertEqual(HwMap.num(o.get("updated")), 20l);
    Test.assertEqual(HwMap.displayColor(o), "pink");
    // only partial parts: a whole-verse part in the new color is added
    var q = HwMap.recolor(HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"PSA.23.2\",\"updated\":30,\"highlights\":[{\"color\":\"blue\",\"start\":4,\"end\":9,\"created\":8}]}") as HwObj, "PSA.23.2", "pink", 20l);
    Test.assertEqual((q.get("highlights") as Lang.Array).size(), 2);
    Test.assertEqual(HwMap.num(q.get("updated")), 31l); // max(now, prev + 1)
    Test.assertEqual(HwMap.displayColor(q), "pink");
    return true;
}

//! A watch range bookmark goes up as one record per verse: N journal ops, each written as
//! highlights:[{color, created}] + updated; deleting one verse of a merged row = one tombstone.
(:test)
function testRangePushPerVerseAndDeleteOne(logger as Test.Logger) as Lang.Boolean {
    var keep = Bookmarks.load();
    Application.Storage.deleteValue(HwSync.S_OPS);
    Bookmarks.save([Bookmarks.packRange(18, 23, 1, 4)] as Lang.Array);
    HwSync.local(Bookmarks.packRange(18, 23, 1, 4), true);
    var ops = Application.Storage.getValue(HwSync.S_OPS) as Lang.Array;
    Test.assertEqual(ops.size(), 4);
    Test.assertEqual((ops[0] as Lang.Array)[0], "PSA.23.1");
    Test.assertEqual((ops[3] as Lang.Array)[0], "PSA.23.4");
    var w = HwMap.edit(null, "PSA.23.3", HwMap.DEFAULT_COLOR, true, 50l);
    var hs = w.get("highlights") as Lang.Array;
    Test.assertEqual(hs.size(), 1);
    Test.assertEqual((hs[0] as HwObj).get("color"), "yellow");
    Test.assertEqual(HwMap.num((hs[0] as HwObj).get("created")), 50l);
    Test.assertEqual(HwMap.num(w.get("updated")), 50l);
    Test.assertEqual(w.get("ref"), "PSA.23.3");
    // Delete verse 2 of the merged row: the stored range splits, one tombstone op for PSA.23.2.
    Application.Storage.deleteValue(HwSync.S_OPS);
    Bookmarks.removeVerse(RmT.ps(23, 2));
    Test.assert(!Bookmarks.hasVerse(RmT.ps(23, 2)));
    Test.assert(Bookmarks.hasVerse(RmT.ps(23, 1)) && Bookmarks.hasVerse(RmT.ps(23, 4)));
    ops = Application.Storage.getValue(HwSync.S_OPS) as Lang.Array;
    Test.assertEqual(ops.size(), 1);
    Test.assertEqual((ops[0] as Lang.Array)[0], "PSA.23.2");
    Test.assertEqual((ops[0] as Lang.Array)[1], false);
    var t = HwMap.edit(w, "PSA.23.2", HwMap.DEFAULT_COLOR, false, 60l);
    Test.assertEqual(t.get("deleted"), true);
    Test.assertEqual(t.get("kind"), "highlight");
    Test.assertEqual(HwMap.num(t.get("updated")), 60l);
    // Recolor journals one op for one verse, with the color.
    Application.Storage.deleteValue(HwSync.S_OPS);
    HwSync.localColor(RmT.ps(23, 3), "pink");
    ops = Application.Storage.getValue(HwSync.S_OPS) as Lang.Array;
    Test.assertEqual(ops.size(), 1);
    Test.assertEqual((ops[0] as Lang.Array)[2], "pink");
    Application.Storage.deleteValue(HwSync.S_OPS);
    Bookmarks.save(keep);
    return true;
}

//! Sub-list of a merged row: its verses that are still bookmarked, in order.
(:test)
function testRangeSubListVerses(logger as Test.Logger) as Lang.Boolean {
    var keep = Bookmarks.load();
    Bookmarks.save([RmT.ps(23, 1), RmT.ps(23, 2), RmT.ps(23, 4)] as Lang.Array);
    var rows = Bookmarks.mergeRows(Bookmarks.load(), null, 100);
    Test.assertEqual(rows.size(), 2);
    var vs = Bookmarks.verses([rows[0]]);
    Test.assertEqual(vs.size(), 2);
    Test.assertEqual(vs[0], RmT.ps(23, 1));
    Test.assertEqual(Bookmarks.formatLabel(vs[1] as Lang.Number), "Psalms 23:2");
    Test.assert(!Bookmarks.isRange(rows[1] as Lang.Number)); // single verse: opens as before
    Bookmarks.save(keep);
    return true;
}

//! 0.9.8: a merged row selects into the reader; HOLD lists its verses (hint only on range rows).
(:test)
function testRangeHoldNotSelect(logger as Test.Logger) as Lang.Boolean {
    var keep = Bookmarks.load();
    Bookmarks.save([RmT.ps(23, 1), RmT.ps(23, 2), RmT.ps(23, 4)] as Lang.Array);
    var rows = Bookmarks.mergeRows(Bookmarks.load(), null, 100);
    var d = new BookmarksMenuDelegate();
    Test.assert(d has :onHoldItem);
    Test.assert(d.holdHint(new P1MenuItem("r", null, rows[0])) != null);
    Test.assert(d.holdHint(new P1MenuItem("s", null, rows[1])) == null);
    Test.assert(d.holdHint(new P1MenuItem("x", null, NativeLists.ID_SYNC)) == null);
    Bookmarks.save(keep);
    return true;
}

//! 0.9.8 marquee: only overflowing text scrolls; a fitted row reports nothing to scroll.
(:test)
function testMarqueeOverflow(logger as Test.Logger) as Lang.Boolean {
    var it = new P1MenuItem("Ps", "short", 1);
    Test.assert(it.mqOver() == 0); // not laid out yet
    Test.assert(it.mq == 0);
    return true;
}
