using Toybox.Application;
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
function testHwMapRefs(logger as Test.Logger) as Lang.Boolean {
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
    Test.assertEqual(HwMap.verseRefs([Bookmarks.pack(42, 3, 16), Bookmarks.pack(42, 3, 16)]).size(), 1); // deduped
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
    // A watch bookmark adds a part in the default color and keeps the other colors' parts.
    var y = HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":2000000000,\"highlights\":[{\"color\":\"c-pray\"}]}") as HwObj;
    var on = HwMap.edit(y, "JHN.3.16", HwMap.DEFAULT_COLOR, true, 1900000000l);
    Test.assertEqual(HwMap.num(on.get("updated")), 2000000001l); // beats what it was made from
    Test.assert(HwMap.inColor(on, "yellow") && HwMap.inColor(on, "c-pray"));
    Test.assertEqual((on.get("highlights") as Lang.Array).size(), 2);
    // Un-bookmarking on the watch deletes the highlight (the list is every color): a tombstone.
    var off = HwMap.edit(on, "JHN.3.16", HwMap.DEFAULT_COLOR, false, 1900000000l);
    Test.assert(off.get("deleted") == true);
    Test.assertEqual(HwJson.stringify(off), "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":2000000002,\"deleted\":true}");
    // A new watch bookmark: one yellow part.
    var only = HwMap.edit(null, "ROM.5.3", HwMap.DEFAULT_COLOR, true, 1900000000l);
    Test.assertEqual(HwJson.stringify(only), "{\"kind\":\"highlight\",\"ref\":\"ROM.5.3\",\"updated\":1900000000,\"highlights\":[{\"color\":\"yellow\",\"created\":1900000000}]}");
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
    var later = HwMap.edit(oa, "JHN.3.16", HwMap.DEFAULT_COLOR, true, 5l);
    Test.assertEqual(HwMap.num(later.get("updated")), 11l);
    Test.assertEqual(HwMap.num(HwMap.edit(oa, "JHN.3.16", HwMap.DEFAULT_COLOR, true, 50l).get("updated")), 50l);
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

//! 0.9.0 kept every record in one Storage value (hwRecs). On the Enduro 3 simulator saving one
//! dict of 250 records (200 is fine) fails with an uncatchable Out Of Memory error (and devices cap
//! values at 32 KB), crashing the sync. The same 800 records in SHARDS dicts store fine.
(:test)
function testHwRecordShardsFitStorage(logger as Test.Logger) as Lang.Boolean {
    var shards = HwT.hwShards(800);
    for (var i = 0; i < HwSync.SHARDS; i++) {
        Application.Storage.setValue("hwTestS" + i, shards[i]);
        Test.assertEqual((Application.Storage.getValue("hwTestS" + i) as Lang.Dictionary).size(), (shards[i] as Lang.Dictionary).size());
        Application.Storage.deleteValue("hwTestS" + i);
    }
    return true;
}

(:test)
module HwT {
var hits as Lang.Number = 0;
function hit() as Void { hits++; }
//! n distinct realistic highlight records, split the way HwSync shards them.
function hwShards(n as Lang.Number) as Lang.Array {
    var rec = "{\"kind\":\"highlight\",\"ref\":\"PSA.119.\",\"updated\":1793000000,\"highlights\":[{\"color\":\"yellow\",\"created\":1792000000}]}";
    var shards = new [HwSync.SHARDS];
    for (var i = 0; i < HwSync.SHARDS; i++) { shards[i] = {}; }
    for (var k = 0; k < n; k++) {
        var id = HwB.b64url(HwKdf.hmac(HwB.utf8("k"), HwB.utf8("" + k))).substring(0, 22) as Lang.String;
        var s = HwSync.recShard(id);
        var d = shards[s] as Lang.Dictionary;
        d[id] = rec + k;
    }
    return shards;
}
}

(:test)
function testHwStatusWords(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(HwSync.why(-104), "phone not connected");
    Test.assertEqual(HwSync.why(401), "sync key not accepted");
    Test.assertEqual(HwSync.why(-300), "timed out: phone offline?");
    Test.assertEqual(HwSync.statusLine("2:51 PM", 412, 7, 412, 0), "ok 2:51 PM: 412 highlights in 7 colors; read 412, sent 0");
    Test.assertEqual(HwSync.statusLine("9:05", 1, 1, 3, 1), "ok 9:05: 1 highlight in 1 color; read 3, sent 1");
    var c = HwSync.clock();
    Test.assert(c.find(":") != null);
    return true;
}

//! 0.9.0 -> 0.9.1: the single hwRecs dict moves into the shards, and records written under this
//! key mean the same library (no start-over); records from another key mean a different one.
(:test)
function testHwLegacyRecsMigrate(logger as Test.Logger) as Lang.Boolean {
    HwSync.wipe();
    HwSync.derive(HwB.parseKey("000G-40R4-0M30-E209-185G-R38E-1YZ0") as Lang.ByteArray);
    var text = "{\"kind\":\"highlight\",\"ref\":\"JHN.3.16\",\"updated\":1,\"highlights\":[{\"color\":\"yellow\"}]}";
    var id = HwSync.itemId("highlight", "JHN.3.16");
    Application.Storage.setValue(HwSync.S_RECS, {id => text});
    Test.assertEqual(HwSync.recGet(id), text);
    Test.assert(Application.Storage.getValue(HwSync.S_RECS) == null);
    Test.assertEqual((Application.Storage.getValue(HwSync.S_REC + HwSync.recShard(id)) as Lang.Dictionary)[id], text);
    Test.assert(HwSync.sameLib());
    HwSync.wipe();
    Application.Storage.setValue(HwSync.S_RECS, {"AAAAAAAAAAAAAAAAAAAAAA" => text}); // id from another key
    Test.assert(!HwSync.sameLib());
    HwSync.wipe();
    Test.assert(HwSync.sameLib()); // nothing stored
    return true;
}

//! Dylan 2:48 PM: every color comes in; the list shows each verse's top color by name.
(:test)
function testHwTopColorAndLabel(logger as Test.Logger) as Lang.Boolean {
    var r = HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"PHP.4.13\",\"updated\":9,\"highlights\":[{\"color\":\"c-pray\",\"created\":5},{\"color\":\"blue\",\"created\":3,\"edited\":8},{\"color\":\"green\",\"created\":7}]}") as HwObj;
    Test.assertEqual(HwMap.topColor(r), "blue"); // edited 8 beats created 7 and 5
    Test.assert(HwMap.topColor(HwJson.parse("{\"kind\":\"highlight\",\"ref\":\"PHP.4.13\",\"deleted\":true}") as HwObj) == null);
    var names = {"c-pray" => "Prayer", "yellow" => "Promises"};
    Test.assertEqual(HwMap.colorLabel("c-pray", names), "Prayer");
    Test.assertEqual(HwMap.colorLabel("yellow", names), "Promises"); // a named built-in
    Test.assertEqual(HwMap.colorLabel("pink", names), "Pink");
    Test.assertEqual(HwMap.colorLabel("c-gone", names), "Color");
    Test.assertEqual(HwMap.DEFAULT_COLOR, "yellow");
    return true;
}

//! Large libraries are the normal case now: 3,000 highlights across 10 colors. The index is
//! sharded (one 0.9.1 value crashed past ~800), every shard is written and read back, and the
//! watch's list takes all 3,000 verses within one Storage value.
(:test)
function testHwIndex3000Highlights(logger as Test.Logger) as Lang.Boolean {
    HwSync.wipe();
    var colors = ["yellow", "green", "blue", "pink", "purple", "orange", "c-pray", "c-hope", "c-work", "c-kids"];
    var cnt = {};
    var n = 0;
    for (var b = 0; b < 66 && n < 3000; b++) {
        for (var c = 1; c <= Books.chapterCount(b) && n < 3000; c++) {
            for (var v = 1; v <= 3 && n < 3000; v++) {
                HwSync.ixSet(HwMap.ref(b, c, v), colors[n % 10] as Lang.String, 1793000000 + n, cnt);
                n++;
            }
        }
    }
    HwSync.ixFlush();
    Test.assertEqual(n, 3000);
    Test.assertEqual(cnt.size(), 10);
    var total = 0;
    for (var i = 0; i < HwSync.IX_SHARDS; i++) {
        var d = Application.Storage.getValue(HwSync.S_IX + i) as Lang.Dictionary;
        Test.assert(d.size() < 300); // spread: ~190 per shard, each value well under 32 KB
        total += d.size();
    }
    Test.assertEqual(total, 3000);
    Test.assertEqual((HwSync.ixGet("GEN.1.1") as Lang.Array)[0], "yellow");
    // Re-coloring and deleting keep the per-color counts right.
    HwSync.ixSet("GEN.1.1", "c-pray", 1793009999, cnt);
    HwSync.ixSet("GEN.1.2", null, 1793009999, cnt);
    Test.assert(cnt.get("yellow") == 299);
    Test.assert(cnt.get("c-pray") == 301);
    Test.assert(cnt.get("green") == 299);
    // The list: 3,000 synced verses in one value.
    Bookmarks.save([] as Lang.Array);
    for (var k = 0; k < 3000; k++) { Bookmarks.syncAdd(k % 66, 1, 1 + k / 66); }
    Test.assert(Bookmarks.syncFlush());
    Test.assertEqual(Bookmarks.load().size(), 3000);
    Bookmarks._cache = null; // read back from Storage
    Test.assertEqual(Bookmarks.load().size(), 3000);
    Bookmarks.save([] as Lang.Array);
    HwSync.wipe();
    return true;
}

//! Remote add/remove on the watch's list: covered verses aren't duplicated, ranges split.
(:test)
function testHwSyncListChanges(logger as Test.Logger) as Lang.Boolean {
    Bookmarks.save([Bookmarks.packRange(44, 5, 3, 5), Bookmarks.pack(18, 23, 0)]);
    Bookmarks.syncAdd(44, 5, 4);   // inside the range: no new row
    Bookmarks.syncAdd(42, 3, 16);
    Bookmarks.syncRemove(44, 5, 4); // splits Rom 5:3-5
    Test.assert(Bookmarks.syncFlush());
    var l = Bookmarks.load();
    Test.assertEqual(l[0], Bookmarks.pack(42, 3, 16)); // newest first
    Test.assert(l.indexOf(Bookmarks.pack(44, 5, 3)) >= 0 && l.indexOf(Bookmarks.pack(44, 5, 5)) >= 0);
    Test.assert(l.indexOf(Bookmarks.pack(18, 23, 0)) >= 0); // chapter bookmark untouched
    Test.assertEqual(l.size(), 4);
    Test.assert(!Bookmarks.syncFlush()); // nothing pending
    Bookmarks.save([] as Lang.Array);
    return true;
}

//! Local changes are journaled per verse (a range = each verse), chapter bookmarks are not.
(:test)
function testHwLocalJournal(logger as Test.Logger) as Lang.Boolean {
    Application.Storage.deleteValue(HwSync.S_OPS);
    HwSync.local(Bookmarks.packRange(44, 5, 3, 4), true);
    HwSync.local(Bookmarks.pack(18, 23, 0), true);
    HwSync.local(Bookmarks.pack(42, 3, 16), false);
    var ops = Application.Storage.getValue(HwSync.S_OPS) as Lang.Array;
    Test.assertEqual(ops.size(), 3);
    Test.assertEqual((ops[1] as Lang.Array)[0], "ROM.5.4");
    Test.assertEqual((ops[2] as Lang.Array)[1], false);
    Test.assertEqual(HwSync.pendingOps()["JHN.3.16"], false);
    Application.Storage.deleteValue(HwSync.S_OPS);
    return true;
}

//! Dylan 3:03 PM: a finished sync (ok or error) reaches the one listener, and the open Bookmarks
//! list rebuilds only when the bookmarks changed (else just its Sync row updates).
(:test)
function testHwSyncFinishedListener(logger as Test.Logger) as Lang.Boolean {
    HwT.hits = 0;
    var was = HwSync.onFinished;
    HwSync.onFinished = new Lang.Method(HwT, :hit);
    HwSync.finished();
    HwSync.fail(-104); // an error ends the sync too
    Test.assertEqual(HwT.hits, 2);
    HwSync.onFinished = was;
    Test.assert(HwSync.shortStatus.find("error") == 0);
    Test.assert(NativeLists.listChanged(3, 4) && !NativeLists.listChanged(4, 4));
    return true;
}
