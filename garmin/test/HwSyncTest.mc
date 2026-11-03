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
