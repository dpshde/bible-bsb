using Toybox.Lang;
using Toybox.Test;

//! Hidden Word sync: crypto vectors (SPEC §10), mapping and merge.

(:test)
function testHwKeyAndVectors(logger as Test.Logger) as Lang.Boolean {
    var k = HwB.parseKey("000G-40R4-0M30-E209-185G-R38E-1YZ0");
    Test.assert(k != null);
    Test.assertEqual(HwB.hex(k as Lang.ByteArray), "000102030405060708090a0b0c0d0e0f");
    Test.assert(HwB.parseKey("000g 40r4 0m30 e209 185g r38e 1yz0") != null); // any case, spaces
    Test.assert(HwB.parseKey("000G-40R4-0M30-E209-185G-R38E-1YZ1") == null); // check byte / padding typo
    Test.assert(HwB.parseKey("000G-40R4") == null);
    Test.assertEqual(HwB.hex(HwKdf.hkdf(k as Lang.ByteArray, null, HwB.utf8("hidden-word/v1/lib"), 16)), "2f4856b70a85a635e64ca60c047e27fb");
    var mac = HwKdf.hkdf(k as Lang.ByteArray, null, HwB.utf8("hidden-word/v1/mac"), 32);
    Test.assertEqual(HwB.b64url(HwKdf.hmac(mac, HwB.utf8("highlight JHN.3.16"))).substring(0, 22), "cq_pOilWI_5HRaH6ll9W2d");
    // SPEC vector blob: decrypt with enc, id as AAD.
    var enc = HwKdf.hkdf(k as Lang.ByteArray, null, HwB.utf8("hidden-word/v1/enc"), 32);
    var b = HwB.fromB64url("AAECAwQFBgcICQoLq8SFwYE8sb0Q7Nvj0LOe6lpQU5r-sMxoBjyo4EP05KSuW7lN79F32bdn56D8EI6iKnaePNLsnxzid7fKUGOpfZj3sFrmQjSdPoLtPeZuBPTPkoPjGnFYloQ4bWNIzu5XtH1NRhcrxGcWHplpjj9yfs6ReI6P7PGUUNUiImUrSskqfI1GJ0vLEVI-puqVYS-90vel6nLEeWTQt-NtECi4kTBs5trpW4Jk4XEpXDi3LePDSOgRuKCRdYWoa-ex8xIGmroNWKFyMhN1M4ngPeikW99IPDk0NOH1wzEaR-KC-CyCflE-P7Dgw3a6BNwzJp3y4twt8SaCmBEDle1zni80Tdr7tecLTIweeXP8LioMAAI");
    var pt = HwGcm.open(enc, b.slice(0, 12), HwB.utf8("cq_pOilWI_5HRaH6ll9W2d"), b.slice(12, null));
    Test.assert(pt != null);
    Test.assertEqual(HwSync.trimEnd(HwB.text(pt as Lang.ByteArray)),
        "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":1793000000,\"highlights\":[{\"color\":\"yellow\",\"created\":1792000000}]}");
    return true;
}

(:test)
function testHwJsonRoundTrip(logger as Test.Logger) as Lang.Boolean {
    var t = "{\"kind\":\"highlight\",\"ref\":\"ROM.5.3\",\"updated\":1793000000,\"x-app\":{\"a\":[1,true,null,\"q\\\"\"]},\"highlights\":[{\"color\":\"c-ab12cd\",\"created\":1792000000}]}";
    var o = HwJson.parse(t);
    Test.assert(o instanceof HwObj);
    Test.assertEqual(HwJson.stringify(o), t); // field order + unknown fields kept
    Test.assert(HwJson.parse("{\"a\":") == null);
    return true;
}

(:test)
function testHwMapRefsAndRuns(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(HwMap.ref(44, 5, 3), "ROM.5.3");
    Test.assertEqual(HwMap.ref(63, 1, 14), "3JN.1.14");
    var p = HwMap.split("JHN.3.16") as Lang.Array;
    Test.assertEqual(p[0], 42); Test.assertEqual(p[1], 3); Test.assertEqual(p[2], 16);
    Test.assert(HwMap.split("JHN.3") == null && HwMap.split("JHN.3.16-18") == null && HwMap.split("XYZ.1.1") == null);
    var list = [Bookmarks.packRange(44, 5, 3, 5), Bookmarks.pack(42, 3, 16), Bookmarks.pack(18, 23, 0)];
    var refs = HwMap.verseRefs(list);
    Test.assertEqual(refs.size(), 4); // chapter bookmark (Ps 23) is not synced
    Test.assertEqual(refs[0], "ROM.5.3");
    Test.assertEqual(refs[2], "ROM.5.5");
    var r = HwMap.runs(["ROM.5.5", "ROM.5.3", "ROM.5.4", "ROM.5.8", "JHN.3.16"]);
    Test.assertEqual(r.size(), 3);
    Test.assert(r.indexOf(Bookmarks.packRange(44, 5, 3, 5)) >= 0);
    Test.assert(r.indexOf(Bookmarks.pack(44, 5, 8)) >= 0);
    Test.assert(r.indexOf(Bookmarks.pack(42, 3, 16)) >= 0);
    return true;
}

(:test)
function testHwApplyDelta(logger as Test.Logger) as Lang.Boolean {
    var list = [Bookmarks.packRange(44, 5, 3, 5), Bookmarks.pack(18, 23, 0)];
    // Another device removed Rom 5:4 and added John 3:16: the range splits, John 3:16 is prepended.
    var out = HwMap.applyDelta(list, ["ROM.5.4"], ["JHN.3.16", "ROM.5.5"]);
    Test.assertEqual(out[0], Bookmarks.pack(42, 3, 16));
    Test.assert(out.indexOf(Bookmarks.pack(44, 5, 3)) >= 0);
    Test.assert(out.indexOf(Bookmarks.pack(44, 5, 5)) >= 0);
    Test.assert(out.indexOf(Bookmarks.pack(18, 23, 0)) >= 0);
    Test.assertEqual(out.size(), 4);
    Test.assertEqual(HwMap.applyDelta(list, [], []).size(), 2); // nothing changed, nothing touched
    return true;
}

(:test)
function testHwMergeAndEdit(logger as Test.Logger) as Lang.Boolean {
    var a = "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":10}";
    var b = "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":9,\"z\":1}";
    var c = "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":10,\"z\":1}";
    var oa = HwJson.parse(a) as HwObj; var ob = HwJson.parse(b) as HwObj; var oc = HwJson.parse(c) as HwObj;
    Test.assert(HwMap.compare(oa, a, ob, b) > 0);   // larger updated wins
    Test.assert(HwMap.compare(oa, a, oc, c) > 0);   // tie: larger UTF-8 text wins ('}' > ',')
    Test.assert(HwMap.compare(oa, a, oa, a) == 0);
    // Bookmarking a verse that has a yellow highlight keeps the yellow part.
    var y = HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":2000000000,\"highlights\":[{\"color\":\"yellow\"}]}") as HwObj;
    var on = HwMap.edit(y, "JHN.3.16", "c-bm", true, 1900000000l);
    Test.assertEqual(HwMap.num(on.get("updated")), 2000000001l); // beats what it was made from
    Test.assert(HwMap.inColor(on, "c-bm"));
    Test.assertEqual((on.get("highlights") as Lang.Array).size(), 2);
    var off = HwMap.edit(on, "JHN.3.16", "c-bm", false, 1900000000l);
    Test.assert(!HwMap.inColor(off, "c-bm") && off.get("deleted") == null);
    // Removing the only part writes a tombstone.
    var only = HwMap.edit(null, "ROM.5.3", "c-bm", true, 1900000000l);
    var gone = HwMap.edit(only, "ROM.5.3", "c-bm", false, 1900000000l);
    Test.assert(gone.get("deleted") == true);
    Test.assertEqual(HwJson.stringify(gone), "{\"kind\":\"highlight\",\"ref\":\"ROM.5.3\",\"updated\":1900000001,\"deleted\":true}");
    return true;
}

//! Forge prod review 1 (SPEC §3): equal `updated` -> the JSON text larger as UTF-8 bytes wins,
//! byte by byte, then the longer text when one is a prefix of the other; local writes beat the
//! version they replace even with a clock that's behind.
(:test)
function testHwTieBreak(logger as Test.Logger) as Lang.Boolean {
    var a = "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":10,\"highlights\":[{\"color\":\"yellow\"}]}";
    var b = "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":10,\"highlights\":[{\"color\":\"blue\"}]}";
    var oa = HwJson.parse(a) as HwObj; var ob = HwJson.parse(b) as HwObj;
    Test.assert(HwMap.compare(oa, a, ob, b) > 0);  // 'y' > 'b' though a is only 2 bytes longer
    Test.assert(HwMap.compare(ob, b, oa, a) < 0);  // symmetric: every device keeps the same one
    var p = "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":10}";
    var q = "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":10} ";
    Test.assert(HwMap.compare(HwJson.parse(q) as HwObj, q, HwJson.parse(p) as HwObj, p) > 0); // prefix: more bytes win
    // Multi-byte UTF-8 compares as bytes: "é" (C3 A9) beats "z" (7A).
    var u = "{\"kind\":\"note\",\"ref\":\"JHN.3.16\",\"updated\":10,\"body\":\"é\"}";
    var z = "{\"kind\":\"note\",\"ref\":\"JHN.3.16\",\"updated\":10,\"body\":\"z\"}";
    Test.assert(HwMap.compare(HwJson.parse(u) as HwObj, u, HwJson.parse(z) as HwObj, z) > 0);
    // Missing / non-integer updated counts as 0.
    var m = "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":\"9\"}";
    var one = "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":1}";
    Test.assert(HwMap.compare(HwJson.parse(one) as HwObj, one, HwJson.parse(m) as HwObj, m) > 0);
    // Writes: updated = max(now, prev + 1).
    var later = HwMap.edit(oa, "JHN.3.16", "c-bm", true, 5l);
    Test.assertEqual(HwMap.num(later.get("updated")), 11l);
    Test.assertEqual(HwMap.num(HwMap.edit(oa, "JHN.3.16", "c-bm", true, 50l).get("updated")), 50l);
    return true;
}

//! Forge prod review 2+3: new color record shape, and picking among duplicate "Bookmarks" colors.
(:test)
function testHwDuplicateBookmarksColors(logger as Test.Logger) as Lang.Boolean {
    var c = HwMap.newColor("c-0a1b2c3d", 1793000000l);
    Test.assertEqual(HwJson.stringify(c),
        "{\"kind\":\"color\",\"ref\":\"c-0a1b2c3d\",\"updated\":1793000000,\"name\":\"Bookmarks\",\"hex\":\"#C89D54\",\"created\":1793000000}");
    Test.assert(HwMap.isBookmarksColor(c));
    Test.assert(!HwMap.isBookmarksColor(HwJson.parse("{\"kind\":\"color\",\"ref\":\"c-x\",\"name\":\"Bookmarks\",\"deleted\":true}") as HwObj));
    Test.assert(!HwMap.isBookmarksColor(HwJson.parse("{\"kind\":\"color\",\"ref\":\"c-y\",\"name\":\"Prayer\",\"hex\":\"#3a7bd5\"}") as HwObj));
    // Lowest created wins, whatever order the records arrived in.
    Test.assertEqual(HwMap.pickColor({"c-watch" => 1793000500l, "c-phone" => 1793000000l, "c-web" => 1793000900l}), "c-phone");
    // Tie on created -> lowest ref (byte order).
    Test.assertEqual(HwMap.pickColor({"c-b2" => 100, "c-a9" => 100, "c-b1" => 100}), "c-a9");
    // Missing created counts as 0 (oldest).
    Test.assertEqual(HwMap.pickColor({"c-new" => 1793000000l, "c-old" => null}), "c-old");
    Test.assert(HwMap.pickColor({}) == null);
    // Duplicates are never merged: bookmarking in the chosen color keeps the other color's part.
    var y = HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"ROM.8.1\",\"updated\":5,\"highlights\":[{\"color\":\"c-watch\",\"created\":4}]}") as HwObj;
    var on = HwMap.edit(y, "ROM.8.1", "c-phone", true, 6l);
    Test.assert(HwMap.inColor(on, "c-phone") && HwMap.inColor(on, "c-watch"));
    Test.assert(HwMap.inColor(HwMap.edit(on, "ROM.8.1", "c-phone", false, 7l), "c-watch"));
    return true;
}

//! Forge prod review 5 (SPEC §5.3): padding, and an item that decrypts but whose kind+ref don't
//! hash to its id is skipped. The blob below is a JHN.3.16 record sealed by the reference client
//! under the id of ROM.5.3 (as AAD), so the GCM tag verifies and only the id check catches it.
(:test)
function testHwItemIdMismatchSkipped(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(HwMap.pad("").size(), 256);
    Test.assertEqual(HwMap.pad("{}").size(), 256);
    var t = "";
    for (var i = 0; i < 257; i++) { t += "a"; }
    var pt = HwMap.pad(t);
    Test.assertEqual(pt.size(), 512);
    Test.assertEqual(pt[257], 0x20);
    Test.assertEqual(pt[511], 0x20);
    HwSync.derive(HwB.parseKey("000G-40R4-0M30-E209-185G-R38E-1YZ0") as Lang.ByteArray);
    var id = "mf7noQVxpGfA4OZlWr9-Az";
    Test.assertEqual(HwSync.itemId("highlight", "ROM.5.3"), id);
    var blob = "BwcHBwcHBwcHBwcH1VrqVwIbhOd1FxPIvSXlUJizi04S7GMuejzt_ueLj_cezVOtjVEKIdWx3YLT8cTZmiVeFEMjKtufpPe-9v52ShQFtQTDwbfjH03v1Rp6huKhuXay3mXrMPiXVoe8OWtBYisvqsHcVBqzq7V4rrLoEIYYVZegQjSgJNQdNzgWT-nmuoRY-wHuffeAYVEaeo_HUBudu1Y8_owbXvQhwFuJhl7Wn80350LbSNcf9JkyNIds1t4EuEZEli9BNwpMQLcrT_DgQulblRtHsJ3LSwmZqG-f1YX_m9XaaPI1868TR_tKKdSBIkaF-44JGZwmm52Dq1w4RYG_BqKyZfbpTfZ46X6TU-H9oEz8POfnvsvKAWE";
    Test.assertEqual(blob.length(), 379); // 12 + 256 + 16 bytes, base64url without padding
    Test.assert(HwSync.openItem(id, blob) == null);
    Test.assert(HwSync.openItem(id, "AAAA") == null); // too short to be an item
    return true;
}

//! The SPEC §10 vector item opens through openItem (tag, padding strip, id check all pass).
(:test)
function testHwOpenItemVector(logger as Test.Logger) as Lang.Boolean {
    HwSync.derive(HwB.parseKey("000G-40R4-0M30-E209-185G-R38E-1YZ0") as Lang.ByteArray);
    var got = HwSync.openItem("cq_pOilWI_5HRaH6ll9W2d", "AAECAwQFBgcICQoLq8SFwYE8sb0Q7Nvj0LOe6lpQU5r-sMxoBjyo4EP05KSuW7lN79F32bdn56D8EI6iKnaePNLsnxzid7fKUGOpfZj3sFrmQjSdPoLtPeZuBPTPkoPjGnFYloQ4bWNIzu5XtH1NRhcrxGcWHplpjj9yfs6ReI6P7PGUUNUiImUrSskqfI1GJ0vLEVI-puqVYS-90vel6nLEeWTQt-NtECi4kTBs5trpW4Jk4XEpXDi3LePDSOgRuKCRdYWoa-ex8xIGmroNWKFyMhN1M4ngPeikW99IPDk0NOH1wzEaR-KC-CyCflE-P7Dgw3a6BNwzJp3y4twt8SaCmBEDle1zni80Tdr7tecLTIweeXP8LioMAAI");
    Test.assert(got != null);
    Test.assertEqual((got as Lang.Array)[0], "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":1793000000,\"highlights\":[{\"color\":\"yellow\",\"created\":1792000000}]}");
    Test.assertEqual(((got as Lang.Array)[1] as HwObj).get("ref"), "JHN.3.16");
    return true;
}

//! Verification 2026-11-03: big items are passed over undecrypted (a 2 KB note tripped the
//! watchdog), and the rescan index never needs the records re-parsed.
(:test)
function testHwBlocksAndIndex(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(HwMap.blocks(379), 1);   // 256-byte plaintext
    Test.assertEqual(HwMap.blocks(721), 2);   // 512
    Test.assertEqual(HwMap.blocks(2768), 8);  // a ~2 KB note: over MAX_BLOCKS, skipped
    Test.assert(HwMap.blocks(2768) > HwSync.MAX_BLOCKS && HwMap.blocks(721) <= HwSync.MAX_BLOCKS);
    var r = HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"PHP.4.13\",\"updated\":1,\"highlights\":[{\"color\":\"c-0older\"},{\"color\":\"yellow\"},{\"color\":\"yellow\"}]}") as HwObj;
    var cs = HwMap.colorsOf(r);
    Test.assertEqual(cs.size(), 2);
    Test.assert(cs.indexOf("c-0older") >= 0 && cs.indexOf("yellow") >= 0);
    Test.assertEqual(HwMap.colorsOf(HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"PHP.4.13\",\"deleted\":true}") as HwObj).size(), 0);
    var s = HwMap.sortStrs(["ROM.5.4", "JHN.3.16", "ROM.5.3"]);
    Test.assertEqual(s[0], "JHN.3.16"); Test.assertEqual(s[2], "ROM.5.4");
    return true;
}
