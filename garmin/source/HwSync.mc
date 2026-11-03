using Toybox.Application;
using Toybox.Communications;
using Toybox.Cryptography;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Timer;
using Toybox.WatchUi;

//! Watch bookmarks <-> Hidden Word highlights (SPEC §1.2: "a highlight in a color named
//! Bookmarks does the same job"). Pure mapping lives here so it can be unit tested.
module HwMap {
    const COLOR_NAME = "Bookmarks";
    const COLOR_HEX = "#C89D54";

    //! "ROM.5.3" (USFM book code, KJV numbering — see versification note in HwSync).
    function ref(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Lang.String {
        return (Books.OSIS[book] as Lang.String) + "." + chapter + "." + verse;
    }

    //! [book, chapter, verse] or null for a ref the watch can't place (chapter refs, ranges, unknown book).
    function split(r as Lang.String) as Lang.Array<Lang.Number> or Null {
        var a = r.find(".");
        if (a == null) { return null; }
        var rest = r.substring(a + 1, null) as Lang.String;
        var b = rest.find(".");
        if (b == null) { return null; }
        var book = Books.OSIS.indexOf(r.substring(0, a));
        var ch = (rest.substring(0, b) as Lang.String).toNumber();
        var vs = rest.substring(b + 1, null) as Lang.String;
        if (vs.find("-") != null) { return null; }
        var v = vs.toNumber();
        if (book < 0 || ch == null || v == null || ch < 1 || v < 1) { return null; }
        return [book, ch, v];
    }

    //! Every verse ref covered by the watch's bookmarks (chapter-level bookmarks are not synced).
    function verseRefs(list as Lang.Array) as Lang.Array<Lang.String> {
        var out = [] as Lang.Array<Lang.String>;
        for (var i = 0; i < list.size(); i++) {
            var id = list[i] as Lang.Number;
            var s = Bookmarks.unpackVerse(id);
            if (s <= 0) { continue; }
            for (var v = s; v <= Bookmarks.unpackEnd(id); v++) {
                var r = ref(Bookmarks.unpackBook(id), Bookmarks.unpackChapter(id), v);
                if (out.indexOf(r) < 0) { out.add(r); }
            }
        }
        return out;
    }

    //! Runs of consecutive verses (same book + chapter) -> packed range bookmark ids.
    function runs(refs as Lang.Array<Lang.String>) as Lang.Array<Lang.Number> {
        var keys = [] as Lang.Array<Lang.Number>; // book*1000+chapter -> verses
        var vss = [] as Lang.Array;
        for (var i = 0; i < refs.size(); i++) {
            var p = split(refs[i]);
            if (p == null) { continue; }
            var k = p[0] * 1000 + p[1];
            var j = keys.indexOf(k);
            if (j < 0) { keys.add(k); vss.add([p[2]]); } else if ((vss[j] as Lang.Array).indexOf(p[2]) < 0) { (vss[j] as Lang.Array).add(p[2]); }
        }
        var out = [] as Lang.Array<Lang.Number>;
        for (var j = 0; j < keys.size(); j++) {
            var vs = sortNums(vss[j] as Lang.Array<Lang.Number>);
            var st = vs[0];
            for (var i = 1; i <= vs.size(); i++) {
                if (i == vs.size() || vs[i] != vs[i - 1] + 1) {
                    out.add(Bookmarks.packRange(keys[j] / 1000, keys[j] % 1000, st, vs[i - 1]));
                    if (i < vs.size()) { st = vs[i]; }
                }
            }
        }
        return out;
    }

    //! Byte-order sort (insertion; lists are short), for stable logs.
    function sortStrs(a as Lang.Array) as Lang.Array {
        for (var i = 1; i < a.size(); i++) {
            var x = a[i] as Lang.String;
            var j = i - 1;
            while (j >= 0 && cmpBytes(HwB.utf8(a[j] as Lang.String), HwB.utf8(x)) > 0) { a[j + 1] = a[j]; j--; }
            a[j + 1] = x;
        }
        return a;
    }

    function sortNums(a as Lang.Array<Lang.Number>) as Lang.Array<Lang.Number> {
        for (var i = 1; i < a.size(); i++) {
            var x = a[i];
            var j = i - 1;
            while (j >= 0 && a[j] > x) { a[j + 1] = a[j]; j--; }
            a[j + 1] = x;
        }
        return a;
    }

    //! Apply what another device changed: verses `removed` leave their bookmarks (a range splits
    //! around them), verses `added` that no bookmark covers become new (newest-first) range bookmarks.
    //! The watch's own ranges, order and chapter bookmarks are otherwise kept.
    function applyDelta(list as Lang.Array, removed as Lang.Array<Lang.String>, added as Lang.Array<Lang.String>) as Lang.Array<Lang.Number> {
        var kept = [] as Lang.Array<Lang.Number>;
        for (var i = 0; i < list.size(); i++) {
            var id = list[i] as Lang.Number;
            var s = Bookmarks.unpackVerse(id);
            if (s <= 0 || removed.size() == 0) { kept.add(id); continue; }
            var b = Bookmarks.unpackBook(id);
            var c = Bookmarks.unpackChapter(id);
            var st = -1;
            for (var v = s; v <= Bookmarks.unpackEnd(id) + 1; v++) {
                var gone = v > Bookmarks.unpackEnd(id) || removed.indexOf(ref(b, c, v)) >= 0;
                if (!gone && st < 0) { st = v; }
                if (gone && st > 0) {
                    var nid = Bookmarks.packRange(b, c, st, v - 1);
                    if (kept.indexOf(nid) < 0) { kept.add(nid); }
                    st = -1;
                }
            }
        }
        var have = verseRefs(kept);
        var fresh = [] as Lang.Array<Lang.String>;
        for (var i = 0; i < added.size(); i++) {
            if (have.indexOf(added[i]) < 0) { fresh.add(added[i]); }
        }
        var out = runs(fresh);
        for (var i = 0; i < kept.size(); i++) {
            if (out.indexOf(kept[i]) < 0) { out.add(kept[i]); }
        }
        return out;
    }

    //! SPEC §3: > 0 when version a beats b. Larger `updated` wins (missing / non-integer = 0).
    //! On a tie the JSON text that is larger as a sequence of UTF-8 bytes wins: compared byte by
    //! byte, and when one text is a prefix of the other, the longer (more bytes) wins. Same as the
    //! reference client's compareVersions (public/sync.js). Texts are exactly as their writers
    //! serialized them (the item plaintext without padding), never re-serialized.
    function compare(a as HwObj, aText as Lang.String, b as HwObj, bText as Lang.String) as Lang.Number {
        var d = num(a.get("updated")) - num(b.get("updated"));
        if (d != 0) { return d > 0 ? 1 : -1; }
        return cmpBytes(HwB.utf8(aText), HwB.utf8(bText));
    }

    //! Unsigned lexicographic byte order; > 0 when x sorts after y.
    function cmpBytes(x as Lang.ByteArray, y as Lang.ByteArray) as Lang.Number {
        var n = x.size() < y.size() ? x.size() : y.size();
        for (var i = 0; i < n; i++) {
            if (x[i] != y[i]) { return x[i] - y[i]; }
        }
        return x.size() - y.size();
    }

    //! 256-byte plaintext blocks in a blob of `chars` base64url characters (nonce 12 + tag 16).
    function blocks(chars as Lang.Number) as Lang.Number {
        var pt = chars * 3 / 4 - 28;
        return pt <= 0 ? 1 : (pt + 255) / 256;
    }

    //! The colors of a live highlight record's parts ([] for a tombstone or another kind).
    function colorsOf(r as HwObj) as Lang.Array {
        var out = [];
        if (r.get("deleted") == true || !"highlight".equals(r.get("kind"))) { return out; }
        var hs = r.get("highlights");
        if (!(hs instanceof Lang.Array)) { return out; }
        for (var i = 0; i < hs.size(); i++) {
            var c = hs[i] instanceof HwObj ? (hs[i] as HwObj).get("color") : null;
            if (c instanceof Lang.String && out.indexOf(c) < 0) { out.add(c); }
        }
        return out;
    }

    //! A color record that can be "the" Bookmarks color: live and named Bookmarks.
    function isBookmarksColor(r as HwObj) as Lang.Boolean {
        return "color".equals(r.get("kind")) && r.get("deleted") != true && COLOR_NAME.equals(r.get("name"));
    }

    //! Which of several "Bookmarks" colors the watch uses (Forge, prod review (b)): the lowest
    //! `created` (missing = 0, like `updated`), then the lowest ref. `cands` is color ref -> created.
    //! Every device picks the same one; duplicates are never deleted or merged.
    function pickColor(cands as Lang.Dictionary) as Lang.String or Null {
        var ks = cands.keys();
        var best = null;
        var bestAt = 0l;
        for (var i = 0; i < ks.size(); i++) {
            var r = ks[i] as Lang.String;
            var at = num(cands[r]);
            if (best == null || at < bestAt || (at == bestAt && cmpBytes(HwB.utf8(r), HwB.utf8(best as Lang.String)) < 0)) {
                best = r;
                bestAt = at;
            }
        }
        return best;
    }

    //! SPEC §5.3 plaintext: UTF-8 JSON padded with spaces to a multiple of 256 bytes, at least 256.
    function pad(text as Lang.String) as Lang.ByteArray {
        var pt = HwB.utf8(text);
        var size = ((pt.size() + 255) / 256) * 256;
        if (size < 256) { size = 256; }
        while (pt.size() < size) { pt.add(0x20); }
        return pt;
    }

    //! A new Bookmarks color record (SPEC §1.4): random `c-` id, gold hex, created.
    function newColor(r as Lang.String, now as Lang.Long) as HwObj {
        return new HwObj().put("kind", "color").put("ref", r).put("updated", now)
            .put("name", COLOR_NAME).put("hex", COLOR_HEX).put("created", now);
    }

    function num(v) as Lang.Long {
        return (v instanceof Lang.Number || v instanceof Lang.Long) ? v.toLong() : 0l;
    }

    //! Does this record put its verse in the Bookmarks color?
    function inColor(r as HwObj or Null, color as Lang.String or Null) as Lang.Boolean {
        if (r == null || color == null || r.get("deleted") == true || !"highlight".equals(r.get("kind"))) { return false; }
        var hs = r.get("highlights");
        if (!(hs instanceof Lang.Array)) { return false; }
        for (var i = 0; i < hs.size(); i++) {
            var h = hs[i];
            if (h instanceof HwObj && color.equals((h as HwObj).get("color"))) { return true; }
        }
        return false;
    }

    //! The record the watch writes when a verse gains (on=true) or loses its Bookmarks part.
    //! Other colors' parts and unknown fields are kept; losing the last part writes a tombstone.
    function edit(old as HwObj or Null, r as Lang.String, color as Lang.String, on as Lang.Boolean, now as Lang.Long) as HwObj {
        var upd = now;
        if (old != null && num(old.get("updated")) + 1 > upd) { upd = num(old.get("updated")) + 1; }
        var live = old != null && old.get("deleted") != true;
        var parts = [] as Lang.Array;
        if (live && (old as HwObj).get("highlights") instanceof Lang.Array) {
            var hs = (old as HwObj).get("highlights") as Lang.Array;
            for (var i = 0; i < hs.size(); i++) {
                if (!(hs[i] instanceof HwObj && color.equals((hs[i] as HwObj).get("color")))) { parts.add(hs[i]); }
            }
        }
        if (on) {
            parts.add(new HwObj().put("color", color).put("created", now));
        }
        if (parts.size() == 0) {
            return new HwObj().put("kind", "highlight").put("ref", r).put("updated", upd).put("deleted", true);
        }
        var o = live ? old as HwObj : new HwObj().put("kind", "highlight").put("ref", r);
        o.put("updated", upd);
        o.put("highlights", parts);
        o.remove("deleted");
        return o;
    }
}

//! Server sync (SPEC §5), hardened to Forge's prod review of the v1 contract (2026-11-03):
//! - Merge (§3): see HwMap.compare; local writes use updated = max(now, prev.updated + 1) (HwMap.edit).
//! - Items (§5.3): openItem / sealItem. Blob = base64url(nonce(12) ‖ ciphertext ‖ tag(16)), AAD =
//!   ASCII item id, plaintext space-padded to a multiple of 256 (min 256), trailing spaces stripped
//!   on read; an item whose decrypted kind+ref doesn't HMAC back to its id is skipped.
//! - Pages: GET asks for `limit=PAGE` (halved on -402/-403, then the cursor steps past a single
//!   too-large item) and follows
//!   `more`. POSTs carry at most POST_MAX items (server cap 100), halved on -102.
//! - Pacing: crypto by 256-byte block budget, record edits EDITS_PER_TICK per tick; items over
//!   MAX_BLOCKS (long notes) are passed over undecrypted.
//! - Bookmarks color: chosen only after a complete pull, lowest `created` then lowest ref among live
//!   colors named Bookmarks (HwMap.pickColor); created by the watch only when none exists.
//! - Refill (§5.6 step 3, watch exception agreed with Forge): after an epoch change or seq going
//!   back the watch re-pushes only its own records, i.e. the highlight records of verses in its
//!   Bookmarks color, that color record and unsent local edits. It keeps no notes, x- kinds or big
//!   items at all, and doesn't re-send other devices' records, so phones and the web refill those.
//! Off unless Garmin Connect settings give a server, a sync key and
//! "Sync bookmarks" = on: then no network call is ever made. Work is paced 1–2 records per
//! timer tick (the watchdog trips around the third 256-byte GCM op in one event).
module HwSync {
    const PROP_SERVER = "hwServer";
    const PROP_KEY = "hwKey";
    const PROP_ON = "hwSync";
    const PROP_STATUS = "hwStatus"; // read-only "Sync status" line shown in Garmin Connect settings
    const S_RECS = "hwRecs";   // legacy (0.9.0): one dict of every record; now sharded, see recMap
    const S_REC = "hwR";       // hwR0..hwR15: item id -> record JSON text, sharded by the id's first char
    const SHARDS = 16;         // one dict of 250 records (~30 KB) crashes Storage.setValue (Out Of Memory,
                               // uncatchable; devices cap values at 32 KB): 16 shards hold ~3,000
    const S_LIB = "hwLib";     // library id the stored state belongs to (a key change starts over)
    const S_NAMES = "hwNames"; // live color ref -> name (for the status line)
    const S_MINE = "hwMine";   // the Bookmarks color the watch created itself, if any
    const S_DIRTY = "hwDirty"; // item ids the server doesn't have yet
    const S_BM = "hwBm";       // verse refs currently in the Bookmarks color
    const S_COLOR = "hwColor";
    const S_CUR = "hwCur";
    const S_SEQ = "hwSeq";
    const S_EPOCH = "hwEpoch";
    const S_IDX = "hwIdx";     // highlight ref -> its colors (so a rescan never re-parses records)
    const S_CANDS = "hwCands"; // live "Bookmarks" color refs -> created
    const PAGE = 30;      // items per GET page: ~13 KB of typical items. The Enduro 3 simulator answers -402
                          // above ~16 KB (limit=37 ok at 15,976 B, limit=40 fails at 17,266 B).
    const MAX_STEPS = 25; // cursor steps past single too-large items per sync (see onPull)
    const POST_MAX = 20;  // items per POST (server cap 100): ~9 KB of typical items; halves on -102
    const PER_TICK = 2;   // 256-byte GCM blocks per timer tick (the watchdog trips around the third)
    const EDITS_PER_TICK = 2; // record parse + re-serialize per tick (5 in one event tripped the watchdog)
    const MAX_BLOCKS = 2; // larger items (long notes, ~22 KB max) are skipped undecrypted: see HwMap.blocks
    const TICK_MS = 50;

    var _keyText as Lang.String or Null = null;
    var _keys as Lang.Array or Null = null; // [lib hex, auth, enc, mac]
    var _timer as Timer.Timer or Null = null;
    var _phase as Lang.Symbol = :idle;
    var _again as Lang.Boolean = false;
    var _applying as Lang.Boolean = false;
    var _queue as Lang.Array = [];
    var _out as Lang.Array = [];
    var _added as Lang.Array<Lang.String> = [];
    var _removed as Lang.Array<Lang.String> = [];
    var _more as Lang.Boolean = false;
    var _page as Lang.Number = PAGE; // halves on a too-large response, for the rest of this sync
    var _steps as Lang.Number = 0;
    var _post as Lang.Number = POST_MAX; // halves on BLE_REQUEST_TOO_LARGE, for the rest of this sync
    var _t0 as Lang.Number = 0;
    var _stats as Lang.Array<Lang.Number> = [0, 0, 0, 0, 0]; // pulled, pushed, skipped, pages, too big
    var lastMs as Lang.Number = -1;
    var lastResult as Lang.String = "";  // the status line (also in Garmin Connect as hwStatus)
    var shortStatus as Lang.String = ""; // fits a Menu2 sublabel (~17 chars)
    var _statusAt as Lang.Number = -100000;
    var _sig as Lang.String or Null = null; // server|on|key the current state was started with
    var _pending as Lang.Boolean = false;   // settings changed mid-sync: restart with them at the end
    var _rc as Lang.Array or Null = null;   // loaded record shards (null = not loaded)
    var _rcDirty as Lang.Array or Null = null;

    function prop(k as Lang.String) {
        try { return Application.Properties.getValue(k); } catch (e) { return null; }
    }

    function server() as Lang.String {
        var s = prop(PROP_SERVER);
        var t = (s instanceof Lang.String && s.length() > 0) ? s as Lang.String : "https://hidden-word.dpshade.workers.dev";
        while (t.length() > 0 && t.substring(t.length() - 1, null).equals("/")) { t = t.substring(0, t.length() - 1) as Lang.String; }
        return t;
    }

    //! Keys when sync is on and the key parses; null = sync off (zero network calls).
    function keys() as Lang.Array or Null {
        if (!(Toybox has :Communications)) { setStatus("this watch can't sync", "can't sync"); return null; }
        if (prop(PROP_ON) != true) { setStatus("sync off", "sync off"); return null; }
        var kt = prop(PROP_KEY);
        if (!(kt instanceof Lang.String) || (kt as Lang.String).length() == 0) {
            setStatus("no key: paste the sync key from Hidden Word", "no sync key");
            return null;
        }
        if (_keys != null && kt.equals(_keyText)) { return _keys; }
        var k = HwB.parseKey(kt as Lang.String);
        if (k == null) { setStatus("key typo: check the sync key (XXXX-XXXX-...)", "key typo"); return null; }
        _keyText = kt as Lang.String;
        derive(k as Lang.ByteArray);
        // State stored for another library (key changed, possibly while the app was closed, when
        // onSettingsChanged never runs) would hide this library's items behind the old cursor.
        var lib = (_keys as Lang.Array)[0] as Lang.String;
        var was = Application.Storage.getValue(S_LIB);
        if (!lib.equals(was) && !(was == null && sameLib())) {
            System.println("HWSYNC new library: starting over");
            wipe();
        }
        Application.Storage.setValue(S_LIB, lib);
        return _keys;
    }

    //! 0.9.0 stored no library id: its records belong to this key when their ids HMAC back.
    function sameLib() as Lang.Boolean {
        for (var i = 0; i < SHARDS; i++) {
            var d = recMap(i);
            var ks = d.keys();
            if (ks.size() == 0) { continue; }
            var r = HwJson.parse(d[ks[0]] as Lang.String);
            if (!(r instanceof HwObj)) { return false; }
            var kind = (r as HwObj).get("kind");
            var rf = (r as HwObj).get("ref");
            return kind instanceof Lang.String && rf instanceof Lang.String
                && itemId(kind as Lang.String, rf as Lang.String).equals(ks[0]);
        }
        return true; // nothing stored: nothing to lose
    }

    function wipe() as Void {
        var ks = [S_RECS, S_DIRTY, S_BM, S_COLOR, S_CUR, S_SEQ, S_EPOCH, S_CANDS, S_IDX, S_NAMES, S_MINE];
        for (var i = 0; i < ks.size(); i++) { Application.Storage.deleteValue(ks[i]); }
        for (var i = 0; i < SHARDS; i++) { Application.Storage.deleteValue(S_REC + i); }
        _rc = null;
        _rcDirty = null;
    }

    // ---- Record store: SHARDS dicts (each well under Storage's 32 KB per value) ----------
    function recShard(id as Lang.String) as Lang.Number {
        var cs = id.toCharArray();
        return cs.size() == 0 ? 0 : cs[0].toNumber() % SHARDS;
    }

    function recMap(i as Lang.Number) as Lang.Dictionary {
        if (_rc == null) {
            _rc = new [SHARDS];
            _rcDirty = new [SHARDS];
            for (var j = 0; j < SHARDS; j++) { (_rcDirty as Lang.Array)[j] = false; }
            var old = Application.Storage.getValue(S_RECS); // 0.9.0: move into the shards once
            if (old instanceof Lang.Dictionary) {
                var ks = (old as Lang.Dictionary).keys();
                for (var j = 0; j < ks.size(); j++) { recPut(ks[j] as Lang.String, (old as Lang.Dictionary)[ks[j]] as Lang.String); }
                recFlush();
                Application.Storage.deleteValue(S_RECS);
            }
        }
        var d = (_rc as Lang.Array)[i];
        if (d == null) {
            d = get(S_REC + i, {});
            (_rc as Lang.Array)[i] = d;
        }
        return d as Lang.Dictionary;
    }

    function recGet(id as Lang.String) as Lang.String or Null {
        return recMap(recShard(id))[id] as Lang.String or Null;
    }

    function recPut(id as Lang.String, text as Lang.String) as Void {
        var i = recShard(id);
        recMap(i)[id] = text;
        (_rcDirty as Lang.Array)[i] = true;
    }

    function recFlush() as Void {
        if (_rc == null) { return; }
        for (var i = 0; i < SHARDS; i++) {
            if ((_rcDirty as Lang.Array)[i] == true) {
                Application.Storage.setValue(S_REC + i, (_rc as Lang.Array)[i]);
                (_rcDirty as Lang.Array)[i] = false;
            }
        }
    }

    // ---- Status line (Garmin Connect "Sync status" + the watch's Bookmarks list) ---------
    //! Never includes the key. Written only when it changes; see settingsChanged for the echo guard.
    function setStatus(text as Lang.String, short as Lang.String) as Void {
        shortStatus = short;
        if (text.length() > 120) { text = text.substring(0, 120) as Lang.String; }
        if (text.equals(lastResult)) { return; }
        lastResult = text;
        System.println("HWSYNC status: " + text);
        _statusAt = System.getTimer();
        try { Application.Properties.setValue(PROP_STATUS, text); } catch (e) { }
    }

    function clock() as Lang.String {
        var i = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var h = i.hour as Lang.Number;
        var m = i.min as Lang.Number;
        var mm = (m < 10 ? "0" : "") + m;
        if (System.getDeviceSettings().is24Hour) { return h + ":" + mm; }
        return (h % 12 == 0 ? 12 : h % 12) + ":" + mm + (h < 12 ? " AM" : " PM");
    }

    //! What a response code means, briefly (negative = the watch / phone / Connect IQ side).
    function why(code as Lang.Number) as Lang.String {
        if (code == 401) { return "sync key not accepted"; }
        if (code == 404) { return "not found: check server URL"; }
        if (code == 413 || code == 400) { return "server refused request"; }
        if (code >= 500) { return "server error"; }
        if (code == 200) { return "unexpected response"; }
        if (code == -104) { return "phone not connected"; }
        if (code == -101) { return "phone link busy"; }
        if (code == -2 || code == -3) { return "phone link timed out"; }
        if (code == -1 || code == -4 || code == -5 || code == -103) { return "Bluetooth error"; }
        if (code == -300) { return "timed out: phone offline?"; }
        if (code == -400 || code == -1002) { return "response not JSON: check server URL"; }
        if (code == -402 || code == -403) { return "response too big"; }
        if (code == -102) { return "request too big"; }
        if (code == -1001) { return "server must use https"; }
        if (code == -1000) { return "watch storage full"; }
        return code < 0 ? "phone/Connect IQ error" : "HTTP error";
    }

    //! The line written when a sync completes: distinguishes an empty library, no Bookmarks color,
    //! a Bookmarks color with no verses, and the normal case.
    function summary() as Void {
        var t = clock();
        var hl = (get(S_IDX, {}) as Lang.Dictionary).size();
        var names = get(S_NAMES, {}) as Lang.Dictionary;
        var color = get(S_COLOR, null);
        var bm = (get(S_BM, []) as Lang.Array).size();
        var tail = " (" + hl + " highlights, " + names.size() + " named colors; read " + _stats[0] + ", sent " + _stats[1] + ")";
        var near = nearMiss(names);
        if (hl == 0 && names.size() == 0 && (get(S_SEQ, 0) as Lang.Number) == 0) {
            setStatus("ok " + t + ": server has no items for this key (empty library?)", "empty library");
        } else if (color == null) {
            setStatus("ok " + t + ": no color named 'Bookmarks'" + near + tail, "no Bookmarks color");
        } else if (color.equals(get(S_MINE, null)) && (get(S_CANDS, {}) as Lang.Dictionary).size() <= 1) {
            setStatus("ok " + t + ": no 'Bookmarks' color on server, watch made one" + near + tail, "ok " + t);
        } else if (bm == 0) {
            setStatus("ok " + t + ": 'Bookmarks' color has 0 verses" + tail, "0 in Bookmarks");
        } else {
            setStatus("ok " + t + ": " + bm + " verses in 'Bookmarks', " + Bookmarks.load().size() + " watch bookmarks" + tail, "ok " + t);
        }
    }

    //! A color named almost "Bookmarks" (case, spaces, singular): the match is exact (SPEC §1.2).
    function nearMiss(names as Lang.Dictionary) as Lang.String {
        var vs = names.values();
        for (var i = 0; i < vs.size(); i++) {
            var n = vs[i];
            if (!(n instanceof Lang.String) || HwMap.COLOR_NAME.equals(n)) { continue; }
            var l = trimEnd(n as Lang.String).toLower();
            while (l.length() > 0 && l.substring(0, 1).equals(" ")) { l = l.substring(1, null) as Lang.String; }
            if (l.equals("bookmarks") || l.equals("bookmark")) { return ": '" + n + "' must be exactly 'Bookmarks'"; }
        }
        return "";
    }

    //! SPEC §5.2: HKDF-SHA256, empty salt, from the 16 key bytes.
    function derive(k as Lang.ByteArray) as Void {
        _keys = [HwB.hex(HwKdf.hkdf(k, null, HwB.utf8("hidden-word/v1/lib"), 16)),
                 HwB.b64url(HwKdf.hkdf(k, null, HwB.utf8("hidden-word/v1/auth"), 32)),
                 HwKdf.hkdf(k, null, HwB.utf8("hidden-word/v1/enc"), 32),
                 HwKdf.hkdf(k, null, HwB.utf8("hidden-word/v1/mac"), 32)];
    }

    //! SPEC §5.3 read: [text, record] or null (bad blob, tag fails, not JSON, no kind/ref, or the
    //! decrypted kind+ref doesn't hash to `id`, which a reader MUST skip).
    function openItem(id as Lang.String, blob as Lang.String) as Lang.Array or Null {
        var b = HwB.fromB64url(blob);
        if (b.size() < 12 + 16 + 256) { return null; } // nonce + tag + at least one 256-byte block
        var pt = HwGcm.open((_keys as Lang.Array)[2] as Lang.ByteArray, b.slice(0, 12), HwB.utf8(id), b.slice(12, null));
        if (pt == null) { return null; }
        var text = trimEnd(HwB.text(pt as Lang.ByteArray));
        var r = HwJson.parse(text);
        if (!(r instanceof HwObj)) { return null; }
        var kind = (r as HwObj).get("kind");
        var rf = (r as HwObj).get("ref");
        if (!(kind instanceof Lang.String) || !(rf instanceof Lang.String)) { return null; }
        if (!id.equals(itemId(kind as Lang.String, rf as Lang.String))) { return null; }
        return [text, r];
    }

    //! SPEC §5.3 write: base64url(nonce ‖ AES-256-GCM(enc, nonce, padded text, aad = id) ‖ tag).
    function sealItem(id as Lang.String, text as Lang.String) as Lang.String {
        var nonce = Cryptography.randomBytes(12);
        var blob = []b;
        blob.addAll(nonce);
        blob.addAll(HwGcm.seal((_keys as Lang.Array)[2] as Lang.ByteArray, nonce, HwB.utf8(id), HwMap.pad(text)));
        return HwB.b64url(blob);
    }

    function itemId(kind as Lang.String, r as Lang.String) as Lang.String {
        var k = _keys as Lang.Array;
        return HwB.b64url(HwKdf.hmac(k[3] as Lang.ByteArray, HwB.utf8(kind + " " + r))).substring(0, 22) as Lang.String;
    }

    function get(k as Lang.String, dflt) {
        var v = Application.Storage.getValue(k);
        return v == null ? dflt : v;
    }

    function sig() as Lang.String {
        return "" + prop(PROP_SERVER) + "|" + prop(PROP_ON) + "|" + prop(PROP_KEY);
    }

    //! Settings changed: drop cached keys and sync (keys() starts over for a different library).
    //! Mid-sync, the running sync finishes first. Our own hwStatus write (or the phone echoing it
    //! back) changes nothing else, so it never starts another sync: no write -> sync loop.
    function settingsChanged() as Void {
        var same = sig().equals(_sig);
        if (_phase != :idle) {
            if (!same) { _pending = true; }
            return;
        }
        if (same && System.getTimer() - _statusAt < 10000) { return; }
        _keys = null;
        _keyText = null;
        start();
    }

    //! Called after the watch's bookmarks change (not for changes sync itself applies).
    function changed() as Void {
        if (!_applying) { start(); }
    }

    function start() as Void {
        if (_phase != :idle) { _again = true; return; }
        _sig = sig();
        if (keys() == null) { return; }
        setStatus("syncing " + clock() + ": keep the app open", "syncing...");
        _t0 = System.getTimer();
        _stats = [0, 0, 0, 0, 0];
        _added = [];
        _removed = [];
        _page = PAGE;
        _steps = 0;
        _post = POST_MAX;
        _phase = :pull;
        pull();
    }

    function headers() as Lang.Dictionary {
        return {"Authorization" => "Bearer " + ((_keys as Lang.Array)[1] as Lang.String),
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON};
    }

    function url() as Lang.String {
        return server() + "/v1/lib/" + ((_keys as Lang.Array)[0] as Lang.String);
    }

    function pull() as Void {
        Communications.makeWebRequest(url() + "?after=" + get(S_CUR, 0) + "&limit=" + _page, null,
            {:method => Communications.HTTP_REQUEST_METHOD_GET, :headers => headers(),
             :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON}, new Lang.Method(HwSync, :onPull));
    }

    function fail(code as Lang.Number) as Void {
        System.println("HWSYNC error " + code + " in " + _phase);
        setStatus("error " + code + " (" + why(code) + ") " + clock(), "error " + code);
        stop();
    }

    //! An exception inside a sync step (e.g. storage full): report it instead of crashing the app.
    function crash(e as Lang.Exception) as Void {
        var m = e.getErrorMessage();
        System.println("HWSYNC exception in " + _phase + ": " + m);
        setStatus("error " + clock() + ": " + (m == null ? "exception" : m), "error");
        _queue = [];
        stop();
    }

    function stop() as Void {
        _phase = :idle;
        _again = false; // tried again on the next change, app start or settings change
        if (_pending) { _pending = false; _keys = null; _keyText = null; start(); }
    }

    //! A server that lost data (new epoch, or seq went back): refill it (SPEC §5.6 step 3).
    function lost(ans as Lang.Dictionary) as Lang.Boolean {
        var ep = get(S_EPOCH, null);
        var seq = ans["seq"];
        return (ep != null && !ep.equals(ans["epoch"])) // a null epoch: the library is gone
            || (seq instanceof Lang.Number && seq < (get(S_SEQ, 0) as Lang.Number));
    }

    //! Watch refill (see module doc): only its own records go back, not every record it holds.
    function refill(ans as Lang.Dictionary) as Void {
        Application.Storage.setValue(S_CUR, 0);
        Application.Storage.setValue(S_SEQ, 0);
        Application.Storage.setValue(S_EPOCH, ans["epoch"]);
        var own = [] as Lang.Array;
        var color = get(S_COLOR, null);
        if (color != null) {
            var cid = itemId("color", color as Lang.String);
            if (recGet(cid) != null) { own.add(cid); }
        }
        var bm = get(S_BM, []) as Lang.Array;
        for (var i = 0; i < bm.size(); i++) {
            var id = itemId("highlight", bm[i] as Lang.String);
            if (recGet(id) != null && own.indexOf(id) < 0) { own.add(id); }
        }
        var dirty = get(S_DIRTY, []) as Lang.Array; // unsent local edits (e.g. tombstones) stay queued
        for (var i = 0; i < dirty.size(); i++) { if (own.indexOf(dirty[i]) < 0) { own.add(dirty[i]); } }
        Application.Storage.setValue(S_DIRTY, own);
    }

    function onPull(code as Lang.Number, data as Null or Lang.Dictionary or Lang.String or Lang.ByteArray or PersistedContent.Iterator) as Void {
        try { pulled(code, data); } catch (e instanceof Lang.Exception) { crash(e); }
    }

    function pulled(code as Lang.Number, data) as Void {
        // -402 response too large / -403 out of memory parsing it: big items (long notes, up to
        // ~22 KB each) can push a page past the watch's response limit. Ask for fewer and retry.
        if ((code == -402 || code == -403) && _page > 1) {
            _page = _page / 2;
            System.println("HWSYNC page too large (" + code + "): limit -> " + _page);
            pull();
            return;
        }
        // Still too large at limit=1: the first item after the cursor is one big item (a long note,
        // never needed on the watch), and every seq between the cursor and it is unused. Step the
        // cursor by one until it's passed; capped per sync, resumed next sync.
        if ((code == -402 || code == -403) && _steps < MAX_STEPS) {
            _steps++;
            if (_steps == 1) { _stats[4] = _stats[4] + 1; }
            Application.Storage.setValue(S_CUR, (get(S_CUR, 0) as Lang.Number) + 1);
            pull();
            return;
        }
        if (code != 200 || !(data instanceof Lang.Dictionary)) { fail(code); return; }
        var ans = data as Lang.Dictionary;
        _stats[3] = _stats[3] + 1;
        if (_steps > 0) { _steps = 0; _page = PAGE; } // past the big item: back to full pages
        if (lost(ans)) { refill(ans); pull(); return; }
        if (ans["epoch"] != null) { Application.Storage.setValue(S_EPOCH, ans["epoch"]); }
        var items = ans["items"] as Lang.Array;
        _queue = items == null ? [] : items;
        _more = ans["more"] == true;
        if (_more) { setStatus("syncing " + clock() + ": " + (_stats[0] + _queue.size()) + " items read, keep the app open", "syncing..."); }
        var seq = ans["seq"];
        if (seq instanceof Lang.Number && seq > (get(S_SEQ, 0) as Lang.Number)) { Application.Storage.setValue(S_SEQ, seq); }
        _phase = :merge;
        tickSoon();
    }

    function tickSoon() as Void {
        if (_timer == null) { _timer = new Timer.Timer(); }
        (_timer as Timer.Timer).start(new Lang.Method(HwSync, :tick), TICK_MS, false);
    }

    function tick() as Void {
        try {
            if (_phase == :merge) { mergeSome(); }
            else if (_phase == :edit) { editSome(); }
            else if (_phase == :seal) { sealSome(); }
        } catch (e instanceof Lang.Exception) { crash(e); }
    }

    //! Decrypt + merge pulled items, PER_TICK 256-byte blocks per tick.
    function mergeSome() as Void {
        var dirty = get(S_DIRTY, []) as Lang.Array;
        var bm = get(S_BM, []) as Lang.Array;
        var cur = get(S_CUR, 0);
        var cands = get(S_CANDS, {}) as Lang.Dictionary;
        var idx = get(S_IDX, {}) as Lang.Dictionary;
        var names = get(S_NAMES, {}) as Lang.Dictionary;
        var budget = PER_TICK;
        while (budget > 0 && _queue.size() > 0) {
            var it = _queue[0] as Lang.Dictionary;
            var id = it["id"];
            var bl = it["blob"];
            var nb = bl instanceof Lang.String ? HwMap.blocks((bl as Lang.String).length()) : 0;
            if (nb > budget && budget < PER_TICK) { break; } // next tick, with a full budget
            _queue = _queue.slice(1, null);
            cur = it["seq"];
            _stats[0] = _stats[0] + 1;
            if (!(id instanceof Lang.String) || !(bl instanceof Lang.String)) { continue; }
            // The watch can't decrypt a big item within one watchdog slice, and only reads small
            // records (highlights, colors), so a big one is passed over unread.
            if (nb > MAX_BLOCKS) { _stats[4] = _stats[4] + 1; continue; }
            budget -= nb;
            var got = openItem(id as Lang.String, bl as Lang.String); // includes the §5.3 id check
            if (got == null) { _stats[2] = _stats[2] + 1; continue; }
            var text = got[0] as Lang.String;
            var r = got[1] as HwObj;
            var kind = r.get("kind") as Lang.String;
            var rf = r.get("ref") as Lang.String;
            if (!"highlight".equals(kind) && !"color".equals(kind)) { continue; } // notes etc. aren't needed on the watch
            var mine = recGet(id as Lang.String);
            var mineObj = mine == null ? null : HwJson.parse(mine as Lang.String) as HwObj;
            var c = mineObj == null ? 1 : HwMap.compare(r as HwObj, text, mineObj as HwObj, mine as Lang.String);
            if (c < 0) { if (dirty.indexOf(id) < 0) { dirty.add(id); } continue; } // ours is newer: resend
            if ("color".equals(kind)) { // for the status line; also on c == 0 (state from 0.9.0 had no names)
                var nm = (r as HwObj).get("name");
                if ((r as HwObj).get("deleted") != true && nm instanceof Lang.String && (nm as Lang.String).length() > 0) { names[rf] = nm; } else { names.remove(rf); }
            }
            if (c == 0) { continue; }
            recPut(id as Lang.String, text);
            if ("highlight".equals(kind)) { index(idx, rf, r); }
            if ("color".equals(kind)) {
                // Picked once the pull is complete (chooseColor), not first-seen.
                if (HwMap.isBookmarksColor(r as HwObj)) { cands[rf] = HwMap.num((r as HwObj).get("created")); } else { cands.remove(rf); }
                continue;
            }
            var color = get(S_COLOR, null);
            var was = bm.indexOf(rf) >= 0;
            var now = HwMap.inColor(r as HwObj, color);
            if (now && !was) { bm.add(rf); noteDelta(rf as Lang.String, true); }
            if (!now && was) { bm.remove(rf); noteDelta(rf as Lang.String, false); }
        }
        recFlush();
        Application.Storage.setValue(S_DIRTY, dirty);
        Application.Storage.setValue(S_BM, bm);
        Application.Storage.setValue(S_CUR, cur);
        Application.Storage.setValue(S_CANDS, cands);
        Application.Storage.setValue(S_IDX, idx);
        Application.Storage.setValue(S_NAMES, names);
        if (_queue.size() > 0) { tickSoon(); return; }
        if (_more) { pull(); return; }
        // The pull is complete: only now pick (or switch) the Bookmarks color.
        var switched = chooseColor();
        // Highlights that arrived before their color record: one scan once the color is known.
        if (get(S_COLOR, null) != null && (_stats[0] > 0 || switched)) { rescan(); }
        apply();
        diff();
    }

    //! After a complete pull: the Bookmarks color every device agrees on. On a switch (e.g. the
    //! watch made its own color offline and an older one turns up) the watch's bookmarks are kept:
    //! verses in the new color are added, and diff() gives the watch's other bookmarks a part in the
    //! new color. Parts in the old color stay as they are (never deleted or merged).
    function chooseColor() as Lang.Boolean {
        var pick = HwMap.pickColor(get(S_CANDS, {}) as Lang.Dictionary);
        var cur = get(S_COLOR, null);
        if (pick == null || pick.equals(cur)) { return false; }
        Application.Storage.setValue(S_COLOR, pick);
        Application.Storage.setValue(S_BM, []);
        if (cur != null) { System.println("HWSYNC Bookmarks color -> the oldest of the duplicates"); }
        return true;
    }

    function noteDelta(r as Lang.String, on as Lang.Boolean) as Void {
        if (on) { _added.add(r); _removed.remove(r); } else { _removed.add(r); _added.remove(r); }
    }

    //! Keep the ref -> colors index in step with a stored highlight record.
    function index(idx as Lang.Dictionary, rf as Lang.String, r as HwObj) as Void {
        var cs = HwMap.colorsOf(r);
        if (cs.size() == 0) { idx.remove(rf); } else { idx[rf] = cs; }
    }

    //! Verses in the Bookmarks color the watch hasn't marked yet, from the index (no JSON parsing:
    //! a full re-parse of a few dozen records trips the watchdog).
    function rescan() as Void {
        var bm = get(S_BM, []) as Lang.Array;
        var color = get(S_COLOR, null);
        var idx = get(S_IDX, {}) as Lang.Dictionary;
        var ks = idx.keys();
        for (var i = 0; i < ks.size(); i++) {
            var rf = ks[i] as Lang.String;
            if ((idx[rf] as Lang.Array).indexOf(color) >= 0 && bm.indexOf(rf) < 0) { bm.add(rf); noteDelta(rf, true); }
        }
        Application.Storage.setValue(S_BM, bm);
    }

    function trimEnd(s as Lang.String) as Lang.String {
        var cs = s.toCharArray();
        var n = cs.size();
        while (n > 0 && cs[n - 1] == ' ') { n--; }
        return s.substring(0, n) as Lang.String;
    }

    //! Remote changes -> the watch's bookmark list.
    function apply() as Void {
        if (_added.size() == 0 && _removed.size() == 0) { return; }
        _applying = true;
        Bookmarks.save(HwMap.applyDelta(Bookmarks.load(), _removed, _added));
        _applying = false;
        WatchUi.requestUpdate();
        System.println("HWSYNC applied +" + _added.size() + " -" + _removed.size() + " verses from the server");
    }

    //! Local bookmark changes -> highlight records (and the Bookmarks color, made once if missing).
    function diff() as Void {
        var want = HwMap.verseRefs(Bookmarks.load());
        var bm = get(S_BM, []) as Lang.Array;
        var dirty = get(S_DIRTY, []) as Lang.Array;
        var now = Time.now().value().toLong();
        var color = get(S_COLOR, null);
        if (color == null && want.size() > 0) {
            // Only reached after a complete pull found no live Bookmarks color.
            color = "c-" + HwB.hex(Cryptography.randomBytes(4));
            var cid = itemId("color", color as Lang.String);
            recPut(cid, HwJson.stringify(HwMap.newColor(color as Lang.String, now)));
            dirty.add(cid);
            Application.Storage.setValue(S_MINE, color);
            var cands = get(S_CANDS, {}) as Lang.Dictionary;
            cands[color] = now;
            Application.Storage.setValue(S_CANDS, cands);
            Application.Storage.setValue(S_COLOR, color);
        }
        recFlush();
        Application.Storage.setValue(S_DIRTY, dirty);
        var edits = [] as Lang.Array;
        for (var i = 0; i < want.size(); i++) { if (bm.indexOf(want[i]) < 0) { edits.add([want[i], true]); } }
        for (var i = 0; i < bm.size(); i++) { if (want.indexOf(bm[i]) < 0) { edits.add([bm[i], false]); } }
        // Each edit parses + re-serializes a record: a handful in one event trips the watchdog,
        // so they're paced like the crypto.
        _queue = edits;
        _phase = :edit;
        tickSoon();
    }

    function editSome() as Void {
        var dirty = get(S_DIRTY, []) as Lang.Array;
        var bm = get(S_BM, []) as Lang.Array;
        var idx = get(S_IDX, {}) as Lang.Dictionary;
        var color = get(S_COLOR, null) as Lang.String;
        var now = Time.now().value().toLong();
        for (var n = 0; n < EDITS_PER_TICK && _queue.size() > 0; n++) {
            var e = _queue[0] as Lang.Array;
            _queue = _queue.slice(1, null);
            var rf = e[0] as Lang.String;
            var id = itemId("highlight", rf);
            var ot = recGet(id);
            var old = ot == null ? null : HwJson.parse(ot as Lang.String) as HwObj;
            var nr = HwMap.edit(old, rf, color, e[1] as Lang.Boolean, now);
            recPut(id, HwJson.stringify(nr));
            index(idx, rf, nr);
            if (dirty.indexOf(id) < 0) { dirty.add(id); }
            if (e[1]) { if (bm.indexOf(rf) < 0) { bm.add(rf); } } else { bm.remove(rf); }
        }
        recFlush();
        Application.Storage.setValue(S_DIRTY, dirty);
        Application.Storage.setValue(S_BM, bm);
        Application.Storage.setValue(S_IDX, idx);
        if (_queue.size() > 0) { tickSoon(); return; }
        _queue = dirty.slice(0, _post);
        _out = [];
        if (_queue.size() == 0) { done(); return; }
        _phase = :seal;
        tickSoon();
    }

    function sealSome() as Void {
        var budget = PER_TICK;
        while (budget > 0 && _queue.size() > 0) {
            var id = _queue[0] as Lang.String;
            var text = recGet(id);
            var nb = text == null ? 0 : ((text as Lang.String).length() + 255) / 256; // ~bytes for these records
            if (nb > budget && budget < PER_TICK) { break; }
            _queue = _queue.slice(1, null);
            if (text == null) { continue; }
            budget -= nb < 1 ? 1 : nb;
            _out.add({"id" => id, "blob" => sealItem(id, text as Lang.String)});
        }
        if (_queue.size() > 0) { tickSoon(); return; }
        if (_out.size() == 0) { done(); return; }
        post();
    }

    function post() as Void {
        _phase = :post;
        Communications.makeWebRequest(url(), {"items" => _out},
            {:method => Communications.HTTP_REQUEST_METHOD_POST, :headers => headers(),
             :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON}, new Lang.Method(HwSync, :onPost));
    }

    function onPost(code as Lang.Number, data as Null or Lang.Dictionary or Lang.String or Lang.ByteArray or PersistedContent.Iterator) as Void {
        try { posted(code, data); } catch (e instanceof Lang.Exception) { crash(e); }
    }

    function posted(code as Lang.Number, data) as Void {
        if (code == -102 && _out.size() > 1) { // BLE_REQUEST_TOO_LARGE: send half; the rest stays dirty
            _post = _out.size() / 2;
            _out = _out.slice(0, _post);
            System.println("HWSYNC request too large: " + _post + " items per POST");
            post();
            return;
        }
        if (code != 200 || !(data instanceof Lang.Dictionary)) { fail(code); return; }
        var ans = data as Lang.Dictionary;
        if (lost(ans)) { refill(ans); _phase = :pull; pull(); return; }
        Application.Storage.setValue(S_EPOCH, ans["epoch"]);
        var sent = [];
        for (var i = 0; i < _out.size(); i++) { sent.add((_out[i] as Lang.Dictionary)["id"]); }
        var dirty = get(S_DIRTY, []) as Lang.Array;
        var left = [];
        for (var i = 0; i < dirty.size(); i++) { if (sent.indexOf(dirty[i]) < 0) { left.add(dirty[i]); } }
        Application.Storage.setValue(S_DIRTY, left);
        var seq = ans["seq"];
        if (seq instanceof Lang.Number && seq > (get(S_SEQ, 0) as Lang.Number)) { Application.Storage.setValue(S_SEQ, seq); }
        _stats[1] = _stats[1] + _out.size();
        if (left.size() > 0) { _queue = left.slice(0, _post); _out = []; _phase = :seal; tickSoon(); return; }
        done();
    }

    function done() as Void {
        lastMs = System.getTimer() - _t0;
        summary();
        System.println("HWSYNC done ms=" + lastMs + " pulled=" + _stats[0] + " pushed=" + _stats[1] + " skipped=" + _stats[2] + " pages=" + _stats[3] + " big=" + _stats[4]
            + " bookmarks=" + Bookmarks.load().size());
        HwTestSeed.report(get(S_COLOR, null), get(S_BM, []) as Lang.Array);
        _phase = :idle;
        if (_pending) { _pending = false; _again = false; _keys = null; _keyText = null; start(); return; }
        if (_again) { _again = false; start(); }
    }
}
