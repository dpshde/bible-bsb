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

//! Watch bookmarks <-> Hidden Word highlights. Dylan 2:48 PM (2026-11-03): the watch shows every
//! highlight of every color as a bookmark (with its color's name), and a bookmark made on the
//! watch is a highlight in Hidden Word's default color. Pure mapping lives here (unit tested).
module HwMap {
    // POKE: WATCH_BOOKMARK_COLOR — a watch bookmark pushes as a part in Hidden Word's default
    // highlight color, never a custom "Bookmarks" color. dpshde/hidden-word-sync@48b7c40:
    // public/app.js:205 a new highlight's color is `... ?? "yellow"`, public/sync.js:9 COLORS
    // starts with "yellow", and SPEC.md:65/:102/:285 an unknown or missing color means yellow.
    // A part's `color` field is required by SPEC §1.2 (no server-side default), so it is sent.
    const DEFAULT_COLOR = "yellow";
    // SPEC §1.4 built-in color ids (named by a `color` record, or shown by id).
    const BUILT_IN = ["yellow", "green", "blue", "pink", "purple", "orange"];

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
    //! Dictionary dedupe: lists now hold thousands of synced highlights.
    function verseRefs(list as Lang.Array) as Lang.Array<Lang.String> {
        var out = [] as Lang.Array<Lang.String>;
        var seen = {};
        for (var i = 0; i < list.size(); i++) {
            var id = list[i] as Lang.Number;
            var s = Bookmarks.unpackVerse(id);
            if (s <= 0) { continue; }
            for (var v = s; v <= Bookmarks.unpackEnd(id); v++) {
                var r = ref(Bookmarks.unpackBook(id), Bookmarks.unpackChapter(id), v);
                if (!seen.hasKey(r)) { seen[r] = true; out.add(r); }
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

    //! The color a highlight shows as: its most recently colored part's (edited, else created,
    //! later parts win ties), same as the reference client's topColor (public/sync.js:229).
    //! null for a tombstone or a record with no parts.
    function topColor(r as HwObj) as Lang.String or Null {
        if (r.get("deleted") == true || !"highlight".equals(r.get("kind"))) { return null; }
        var hs = r.get("highlights");
        if (!(hs instanceof Lang.Array)) { return null; }
        var best = null;
        var bestAt = 0l;
        for (var i = 0; i < hs.size(); i++) {
            if (!(hs[i] instanceof HwObj)) { continue; }
            var h = hs[i] as HwObj;
            var c = h.get("color");
            if (!(c instanceof Lang.String)) { continue; }
            var at = h.get("edited") != null ? num(h.get("edited")) : num(h.get("created"));
            if (best == null || at >= bestAt) { best = c; bestAt = at; }
        }
        return best;
    }

    //! A part with no `start` and no `end` covers the whole verse (SPEC 1.2).
    function isWhole(h as HwObj) as Lang.Boolean {
        return h.get("start") == null && h.get("end") == null;
    }

    //! The color a verse shows as in the Bookmarks list and for range merging (Hidden Word web,
    //! SPEC 1.2): the whole-verse part's color (the most recently colored one if several), else
    //! the top part's (topColor: largest edited, else created). null for a tombstone / no parts.
    function displayColor(r as HwObj) as Lang.String or Null {
        if (r.get("deleted") == true || !"highlight".equals(r.get("kind"))) { return null; }
        var hs = r.get("highlights");
        if (!(hs instanceof Lang.Array)) { return null; }
        var best = null;
        var bestAt = 0l;
        for (var i = 0; i < hs.size(); i++) {
            if (!(hs[i] instanceof HwObj) || !isWhole(hs[i] as HwObj)) { continue; }
            var h = hs[i] as HwObj;
            var c = h.get("color");
            if (!(c instanceof Lang.String)) { continue; }
            var at = h.get("edited") != null ? num(h.get("edited")) : num(h.get("created"));
            if (best == null || at >= bestAt) { best = c; bestAt = at; }
        }
        return best != null ? best : topColor(r);
    }

    //! Recolor one verse's record (watch Bookmarks > range > verse > Recolor): every whole-verse
    //! part takes `color` (edited = now); with none, a whole-verse part in `color` is added.
    //! Partial parts, notes and unknown fields are kept (SPEC: copy, change, write back whole).
    //! A dead / unknown record becomes a new one-part record (same as a watch bookmark).
    function recolor(old as HwObj or Null, r as Lang.String, color as Lang.String, now as Lang.Long) as HwObj {
        if (old == null || old.get("deleted") == true || !((old as HwObj).get("highlights") instanceof Lang.Array)) {
            return edit(old, r, color, true, now);
        }
        var o = old as HwObj;
        var upd = now;
        if (num(o.get("updated")) + 1 > upd) { upd = num(o.get("updated")) + 1; }
        var hs = o.get("highlights") as Lang.Array;
        var whole = false;
        for (var i = 0; i < hs.size(); i++) {
            if (hs[i] instanceof HwObj && isWhole(hs[i] as HwObj)) {
                (hs[i] as HwObj).put("color", color);
                (hs[i] as HwObj).put("edited", now);
                whole = true;
            }
        }
        if (!whole) { hs.add(new HwObj().put("color", color).put("created", now)); }
        o.put("highlights", hs);
        o.put("updated", upd);
        return o;
    }

    //! What the Bookmarks list shows for a color id: the library's name for it, else the
    //! built-in id capitalized ("Yellow"); a nameless custom color shows "Color".
    function colorLabel(id as Lang.String, names as Lang.Dictionary) as Lang.String {
        var n = names[id];
        if (n instanceof Lang.String && (n as Lang.String).length() > 0) { return n as Lang.String; }
        if (BUILT_IN.indexOf(id) >= 0) { return id.substring(0, 1).toUpper() + id.substring(1, null); }
        return "Color";
    }

    //! SPEC §5.3 plaintext: UTF-8 JSON padded with spaces to a multiple of 256 bytes, at least 256.
    function pad(text as Lang.String) as Lang.ByteArray {
        var pt = HwB.utf8(text);
        var size = ((pt.size() + 255) / 256) * 256;
        if (size < 256) { size = 256; }
        while (pt.size() < size) { pt.add(0x20); }
        return pt;
    }

    function num(v) as Lang.Long {
        return (v instanceof Lang.Number || v instanceof Lang.Long) ? v.toLong() : 0l;
    }

    //! Does this record have a part in `color`?
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

    //! The record the watch writes when a verse is bookmarked (on=true: a part in `color` is added,
    //! other colors' parts and unknown fields kept) or un-bookmarked (on=false: a tombstone, since
    //! the watch's list is every highlight of every color, removing one deletes the highlight).
    //! POKE: WATCH_REMOVE_DELETES — un-bookmarking on the watch deletes the verse's highlight in
    //! every color (the list shows all colors as one bookmark).
    function edit(old as HwObj or Null, r as Lang.String, color as Lang.String, on as Lang.Boolean, now as Lang.Long) as HwObj {
        var upd = now;
        if (old != null && num(old.get("updated")) + 1 > upd) { upd = num(old.get("updated")) + 1; }
        if (!on) {
            return new HwObj().put("kind", "highlight").put("ref", r).put("updated", upd).put("deleted", true);
        }
        var live = old != null && old.get("deleted") != true;
        var parts = [] as Lang.Array;
        if (live && (old as HwObj).get("highlights") instanceof Lang.Array) {
            var hs = (old as HwObj).get("highlights") as Lang.Array;
            for (var i = 0; i < hs.size(); i++) {
                if (!(hs[i] instanceof HwObj && color.equals((hs[i] as HwObj).get("color")))) { parts.add(hs[i]); }
            }
        }
        parts.add(new HwObj().put("color", color).put("created", now));
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
//! - Colors (Dylan 2:48 PM): every highlight of every color is pulled. Others' highlights are kept
//!   as a compact index (ref -> [top color, updated], IX_SHARDS values), not as record texts; the
//!   watch keeps full texts only of records it wrote (for the §3 tie-break and refill). A watch
//!   bookmark is a part in HwMap.DEFAULT_COLOR ("yellow"); no color record is ever created.
//! - Local changes are journaled (S_OPS, from Bookmarks.toggle/addRange/remove), not diffed
//!   against the whole list: a diff of thousands of verses trips the watchdog.
//! - Refill (§5.6 step 3, watch exception agreed with Forge): after an epoch change or seq going
//!   back the watch re-pushes only its own records (the ones it wrote) and unsent edits; phones
//!   and the web refill the rest.
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
    const S_NAMES = "hwNames"; // color ref -> name (Bookmarks list labels)
    const S_HEX = "hwHex";     // color ref -> "#RRGGBB" when the color record gives one
    const S_OKAT = "hwOkAt";   // Unix time of the last sync that ended ok (home menu "synced 4m ago")
    const S_DIRTY = "hwDirty"; // item ids the server doesn't have yet
    const S_CUR = "hwCur";
    const S_SEQ = "hwSeq";
    const S_EPOCH = "hwEpoch";
    // Highlight index, sharded like the records: hwX0..hwX15, verse ref -> [top color, updated].
    // 0.9.1 kept it in one value (hwIdx), which crashes Storage.setValue past ~800 highlights.
    const S_IX = "hwX";
    const IX_SHARDS = 16;      // 3,000 highlights = ~190 per shard, ~7 KB each
    const IX_CACHED = 4;       // shards held in memory at once (LRU), the rest stay in Storage
    const S_CNT = "hwCnt";     // color ref -> highlights in it (status line)
    const S_OPS = "hwOps";     // journal of local bookmark changes: [verse ref, on]
    const MAX_OPS = 300;       // past this the journal restarts from the whole list (S_SEEDED)
    const S_SEEDED = "hwSeed"; // the watch's own list has been journaled for this library
    const S_PSEED = "hwPSeed"; // personal build: sync was switched on once (seedPersonal)
    const S_VER = "hwVer";     // state layout; 2 = all colors (0.9.2). Older state is rebuilt.
    const VER = 2;
    // 0.9.1 keys (Bookmarks color era), removed by wipe().
    const LEGACY = ["hwBm", "hwColor", "hwIdx", "hwCands", "hwMine"];
    const PAGE = 30;      // items per GET page: ~13 KB of typical items. The Enduro 3 simulator answers -402
                          // above ~16 KB (limit=37 ok at 15,976 B, limit=40 fails at 17,266 B).
    const MAX_STEPS = 25; // cursor steps past single too-large items per sync (see onPull)
    const POST_MAX = 20;  // items per POST (server cap 100): ~9 KB of typical items; halves on -102
    // 0.9.8 (Dylan, real Enduro 3: "UI freezes while syncing"): one item per tick, and a page's
    // state is held in memory and written back one Storage value per tick (FLUSH_PER_TICK) at
    // the page end. 0.9.7 re-read and re-wrote 5 values + index/record shards on every tick.
    const PER_TICK = 1;   // 256-byte GCM blocks per timer tick (the watchdog trips around the third)
    const FLUSH_PER_TICK = 1; // Storage.setValue calls per tick while a page is written back
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
    var _ix as Lang.Dictionary = {};        // loaded index shards: shard -> dict
    var _ixDirty as Lang.Dictionary = {};   // shard -> true
    var _ixOrder as Lang.Array = [];        // load order (LRU eviction)

    function prop(k as Lang.String) {
        try { return Application.Properties.getValue(k); } catch (e) { return null; }
    }

    //! The sync key: Garmin Connect's "Sync key" setting, else a personal build's baked-in key
    //! (PersonalSync, generated outside the repo by tools/make_personal_sync.sh; stub: null).
    function keyText() as Lang.String or Null {
        var kt = prop(PROP_KEY);
        if (kt instanceof Lang.String && (kt as Lang.String).length() > 0) { return kt as Lang.String; }
        return PersonalSync.key();
    }

    function hasKey() as Lang.Boolean {
        return keyText() != null;
    }

    function isOn() as Lang.Boolean {
        return prop(PROP_ON) == true;
    }

    //! In-app Settings "Hidden Word sync" (0.9.7): writes the same hwSync setting Connect shows.
    function setOn(on as Lang.Boolean) as Void {
        try { Application.Properties.setValue(PROP_ON, on); } catch (e) { }
        settingsChanged();
    }

    //! Personal builds only: turn sync on once, the first launch with a baked-in key. A sideload
    //! keeps the watch's stored settings (0.9.5: sync off), so new defaults never reach it; later
    //! in-app or Connect changes win (the seed never runs again).
    function seedPersonal() as Void {
        if (PersonalSync.key() == null || Application.Storage.getValue(S_PSEED) == true) { return; }
        Application.Storage.setValue(S_PSEED, true);
        try { Application.Properties.setValue(PROP_ON, true); } catch (e) { }
    }

    function server() as Lang.String {
        var s = prop(PROP_SERVER);
        var t = (s instanceof Lang.String && s.length() > 0) ? s as Lang.String : "https://vault.selah.tools";
        while (t.length() > 0 && t.substring(t.length() - 1, null).equals("/")) { t = t.substring(0, t.length() - 1) as Lang.String; }
        return t;
    }

    //! Keys when sync is on and the key parses; null = sync off (zero network calls).
    function keys() as Lang.Array or Null {
        if (!(Toybox has :Communications)) { setStatus("this watch can't sync", "can't sync"); return null; }
        if (!isOn()) { setStatus("sync off", "sync off"); return null; }
        var kt = keyText();
        if (!(kt instanceof Lang.String) || (kt as Lang.String).length() == 0) {
            setStatus("no key: paste the sync key from Selah Vault", "no sync key");
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
            Perf.log("HWSYNC new library: starting over");
            purgeSynced(); // the old library's highlights leave the watch's list; its own bookmarks stay
            wipe();
        } else if (get(S_VER, 1) != VER) {
            Perf.log("HWSYNC state from 0.9.1: re-reading the library (all colors)");
            wipe();
        }
        Application.Storage.setValue(S_LIB, lib);
        Application.Storage.setValue(S_VER, VER);
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
        var ks = [S_RECS, S_DIRTY, S_CUR, S_SEQ, S_EPOCH, S_NAMES, S_HEX, S_OKAT, S_CNT, S_OPS, S_SEEDED];
        ks.addAll(LEGACY);
        for (var i = 0; i < ks.size(); i++) { Application.Storage.deleteValue(ks[i]); }
        for (var i = 0; i < SHARDS; i++) { Application.Storage.deleteValue(S_REC + i); }
        for (var i = 0; i < IX_SHARDS; i++) { Application.Storage.deleteValue(S_IX + i); }
        _rc = null;
        _rcDirty = null;
        _ix = {};
        _ixDirty = {};
        _ixOrder = [];
    }

    //! Key changed to another library: drop the old library's highlights from the watch's list
    //! (verses in the index), keeping bookmarks that were only ever on the watch.
    function purgeSynced() as Void {
        for (var i = 0; i < IX_SHARDS; i++) {
            var d = get(S_IX + i, {}) as Lang.Dictionary;
            var ks = d.keys();
            for (var j = 0; j < ks.size(); j++) {
                var p = HwMap.split(ks[j] as Lang.String);
                if (p != null) { Bookmarks.syncRemove(p[0], p[1], p[2]); }
            }
        }
        Bookmarks.syncFlush();
    }

    // ---- Highlight index: IX_SHARDS dicts, at most IX_CACHED in memory -------------------
    function ixShard(rf as Lang.String) as Lang.Number {
        var cs = rf.toCharArray();
        var h = 0;
        for (var i = 0; i < cs.size(); i++) { h = h * 31 + cs[i].toNumber(); h = h & 0xFFFFFF; }
        return h % IX_SHARDS;
    }

    function ixMap(i as Lang.Number) as Lang.Dictionary {
        var d = _ix[i];
        if (d != null) { return d as Lang.Dictionary; }
        if (_ixOrder.size() >= IX_CACHED) {
            var old = _ixOrder[0] as Lang.Number;
            _ixOrder = _ixOrder.slice(1, null);
            if (_ixDirty[old] == true) { Application.Storage.setValue(S_IX + old, _ix[old]); _ixDirty.remove(old); }
            _ix.remove(old);
        }
        d = get(S_IX + i, {});
        _ix[i] = d;
        _ixOrder.add(i);
        return d as Lang.Dictionary;
    }

    //! [top color, updated] or null.
    function ixGet(rf as Lang.String) as Lang.Array or Null {
        return ixMap(ixShard(rf))[rf] as Lang.Array or Null;
    }

    //! color null = the verse has no live highlight (entry removed). Keeps S_CNT in step.
    function ixSet(rf as Lang.String, color as Lang.String or Null, upd as Lang.Number, cnt as Lang.Dictionary) as Void {
        var i = ixShard(rf);
        var d = ixMap(i);
        var was = d[rf] as Lang.Array or Null;
        if (was != null) {
            var n = cnt[was[0]];
            if (n instanceof Lang.Number) { if (n <= 1) { cnt.remove(was[0]); } else { cnt[was[0]] = n - 1; } }
        }
        if (color == null) { d.remove(rf); } else {
            d[rf] = [color, upd];
            var n = cnt[color];
            cnt[color] = n instanceof Lang.Number ? n + 1 : 1;
        }
        _ixDirty[i] = true;
    }

    function ixFlush() as Void {
        var ks = _ixDirty.keys();
        for (var j = 0; j < ks.size(); j++) { Application.Storage.setValue(S_IX + ks[j], _ix[ks[j]]); }
        _ixDirty = {};
    }

    //! Bookmarks list colors: packed bookmark id -> color id (displayColor at pull time), for
    //! single-verse ids the index knows. Resolved shard by shard (one shard in memory at a time).
    function colorIds(ids as Lang.Array) as Lang.Dictionary {
        var out = {};
        if ((get(S_CNT, {}) as Lang.Dictionary).size() == 0) { return out; }
        var by = {}; // shard -> [[id, ref], ...]
        for (var i = 0; i < ids.size(); i++) {
            var id = ids[i] as Lang.Number;
            var v = Bookmarks.unpackVerse(id);
            if (v <= 0) { continue; }
            var rf = HwMap.ref(Bookmarks.unpackBook(id), Bookmarks.unpackChapter(id), v);
            var sh = ixShard(rf);
            if (by[sh] == null) { by[sh] = []; }
            (by[sh] as Lang.Array).add([id, rf]);
        }
        var ks = by.keys();
        for (var j = 0; j < ks.size(); j++) {
            var d = _ix[ks[j]] != null ? _ix[ks[j]] as Lang.Dictionary : get(S_IX + ks[j], {}) as Lang.Dictionary;
            var rows = by[ks[j]] as Lang.Array;
            for (var k = 0; k < rows.size(); k++) {
                var e = d[(rows[k] as Lang.Array)[1]];
                if (e != null) { out[(rows[k] as Lang.Array)[0]] = (e as Lang.Array)[0]; }
            }
        }
        return out;
    }

    //! Bookmarks list labels: packed bookmark id -> color label (colorIds, named).
    function colorLabels(ids as Lang.Array) as Lang.Dictionary {
        var c = colorIds(ids);
        var names = get(S_NAMES, {}) as Lang.Dictionary;
        var ks = c.keys();
        for (var i = 0; i < ks.size(); i++) { c[ks[i]] = HwMap.colorLabel(c[ks[i]] as Lang.String, names); }
        return c;
    }

    function colorName(id as Lang.String or Null) as Lang.String or Null {
        return id == null ? null : HwMap.colorLabel(id as Lang.String, get(S_NAMES, {}) as Lang.Dictionary);
    }

    //! Recolor choices: [[color id, label], ...]: the built-ins, then the library's named colors.
    function colorChoices() as Lang.Array {
        var names = get(S_NAMES, {}) as Lang.Dictionary;
        var out = [] as Lang.Array;
        for (var i = 0; i < HwMap.BUILT_IN.size(); i++) {
            out.add([HwMap.BUILT_IN[i], HwMap.colorLabel(HwMap.BUILT_IN[i] as Lang.String, names)]);
        }
        var ks = names.keys();
        for (var i = 0; i < ks.size(); i++) {
            if (HwMap.BUILT_IN.indexOf(ks[i]) < 0) { out.add([ks[i], HwMap.colorLabel(ks[i] as Lang.String, names)]); }
        }
        return out;
    }

    //! Journal a recolor of one verse (single packed verse id): [ref, true, color].
    function localColor(id as Lang.Number, color as Lang.String) as Void {
        var v = Bookmarks.unpackVerse(id);
        if (v <= 0) { return; }
        var ops = get(S_OPS, []) as Lang.Array;
        ops.add([HwMap.ref(Bookmarks.unpackBook(id), Bookmarks.unpackChapter(id), v), true, color]);
        if (ops.size() > MAX_OPS) { ops = []; Application.Storage.setValue(S_SEEDED, false); }
        Application.Storage.setValue(S_OPS, ops);
    }

    //! Bookmarks.toggle / addRange / remove: journal the change for the next sync (even with sync
    //! off, so bookmarks made before sync was set up still go up).
    function local(id as Lang.Number, on as Lang.Boolean) as Void {
        var s = Bookmarks.unpackVerse(id);
        if (s <= 0) { return; } // chapter bookmarks aren't synced
        var ops = get(S_OPS, []) as Lang.Array;
        for (var v = s; v <= Bookmarks.unpackEnd(id); v++) {
            ops.add([HwMap.ref(Bookmarks.unpackBook(id), Bookmarks.unpackChapter(id), v), on]);
        }
        if (ops.size() > MAX_OPS) { ops = []; Application.Storage.setValue(S_SEEDED, false); }
        Application.Storage.setValue(S_OPS, ops);
    }

    //! First sync for a library: every verse on the watch's list goes up (verses the library
    //! already highlights are skipped in editSome).
    function seed() as Void {
        if (get(S_SEEDED, false) == true) { return; }
        var refs = HwMap.verseRefs(Bookmarks.load());
        var ops = [] as Lang.Array;
        for (var i = 0; i < refs.size() && i < MAX_OPS; i++) { ops.add([refs[i], true]); }
        Application.Storage.setValue(S_OPS, ops);
        Application.Storage.setValue(S_SEEDED, true);
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
        Perf.log("HWSYNC status: " + text);
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

    //! The line written when a sync completes: "ok 2:51 PM: 412 highlights in 7 colors; read 412, sent 0".
    function summary() as Void {
        var t = clock();
        var cnt = get(S_CNT, {}) as Lang.Dictionary;
        var hl = 0;
        var vs = cnt.values();
        for (var i = 0; i < vs.size(); i++) { hl += vs[i] as Lang.Number; }
        if (hl == 0 && (get(S_SEQ, 0) as Lang.Number) == 0) {
            setStatus("ok " + t + ": server has no items for this key (empty library?)", "empty library");
            return;
        }
        setStatus(statusLine(t, hl, cnt.size(), _stats[0], _stats[1]), "ok " + t);
    }

    function statusLine(t as Lang.String, hl as Lang.Number, colors as Lang.Number, read as Lang.Number, sent as Lang.Number) as Lang.String {
        return "ok " + t + ": " + hl + (hl == 1 ? " highlight in " : " highlights in ") + colors
            + (colors == 1 ? " color" : " colors") + "; read " + read + ", sent " + sent;
    }

    //! Home menu "Bookmarks" sublabel (critique #11), short enough for a Menu2 sublabel:
    //! "2 saved" (sync off), "2 · synced 4m ago", "2 · sync error", "2 · syncing…".
    function bookmarksLine(n as Lang.Number) as Lang.String {
        var count = n == 0 ? "None yet" : (n == 1 ? "1 saved" : n + " saved");
        if (!isOn()) { return count; }
        var lead = n + " · ";
        if (_phase != :idle) { return lead + "syncing…"; }
        if (lastResult.find("error") == 0 || lastResult.find("key") == 0 || lastResult.find("no key") == 0) { return lead + "sync error"; }
        var at = Application.Storage.getValue(S_OKAT);
        if (!(at instanceof Lang.Number)) { return count; }
        var m = (Time.now().value() - (at as Lang.Number)) / 60;
        if (m < 1) { return lead + "synced now"; }
        if (m < 60) { return lead + "synced " + m + "m ago"; }
        if (m < 48 * 60) { return lead + "synced " + (m / 60) + "h ago"; }
        return lead + "synced " + (m / 1440) + "d ago";
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
        return "" + prop(PROP_SERVER) + "|" + isOn() + "|" + keyText();
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
        if (keys() == null) { finished(); return; }
        setStatus("syncing " + clock() + ": keep the app open", "syncing...");
        seed();
        _t0 = System.getTimer();
        _ms = null;
        _wq = [] as Lang.Array;
        sliceN = 0;
        sliceMax = 0;
        sliceTotal = 0;
        _stats = [0, 0, 0, 0, 0];
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
        Perf.log("HWSYNC error " + code + " in " + _phase);
        setStatus("error " + code + " (" + why(code) + ") " + clock(), "error " + code);
        stop();
    }

    //! An exception inside a sync step (e.g. storage full): report it instead of crashing the app.
    function crash(e as Lang.Exception) as Void {
        var m = e.getErrorMessage();
        Perf.log("HWSYNC exception in " + _phase + ": " + m);
        setStatus("error " + clock() + ": " + (m == null ? "exception" : m), "error");
        _queue = [];
        stop();
    }

    //! The one sync-finished hook (ok, error, or nothing to do): screens showing sync state
    //! refresh from it (NativeLists.onSyncFinished, set in getInitialView). Not a timer.
    var onFinished as Lang.Method or Null = null;

    function finished() as Void {
        var f = onFinished;
        if (f != null) { (f as Lang.Method).invoke(); }
    }

    function stop() as Void {
        _phase = :idle;
        _again = false; // tried again on the next change, app start or settings change
        finished();
        if (_pending) { _pending = false; _keys = null; _keyText = null; start(); }
    }

    //! A server that lost data (new epoch, or seq went back): refill it (SPEC §5.6 step 3).
    function lost(ans as Lang.Dictionary) as Lang.Boolean {
        var ep = get(S_EPOCH, null);
        var seq = ans["seq"];
        return (ep != null && !ep.equals(ans["epoch"])) // a null epoch: the library is gone
            || (seq instanceof Lang.Number && seq < (get(S_SEQ, 0) as Lang.Number));
    }

    //! Watch refill (see module doc): only its own records go back, not every highlight it knows.
    function refill(ans as Lang.Dictionary) as Void {
        Application.Storage.setValue(S_CUR, 0);
        Application.Storage.setValue(S_SEQ, 0);
        Application.Storage.setValue(S_EPOCH, ans["epoch"]);
        var own = get(S_DIRTY, []) as Lang.Array; // unsent local edits (e.g. tombstones) stay queued
        for (var i = 0; i < SHARDS; i++) {
            var ks = recMap(i).keys();
            for (var j = 0; j < ks.size(); j++) { if (own.indexOf(ks[j]) < 0) { own.add(ks[j]); } }
        }
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
            Perf.log("HWSYNC page too large (" + code + "): limit -> " + _page);
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
        var t0 = System.getTimer();
        try {
            if (_phase == :merge) { mergeSome(); }
            else if (_phase == :flush) { flushSome(); }
            else if (_phase == :edit) { editSome(); }
            else if (_phase == :seal) { sealSome(); }
        } catch (e instanceof Lang.Exception) { crash(e); }
        var ms = System.getTimer() - t0;
        sliceN++;
        sliceTotal += ms;
        if (ms > sliceMax) { sliceMax = ms; }
    }

    // Slice probe (0.9.8): timer slices this sync, their longest and total ms (HWSYNC done line).
    var sliceN as Lang.Number = 0;
    var sliceMax as Lang.Number = 0;
    var sliceTotal as Lang.Number = 0;

    //! Local changes not yet written as records: verse ref -> on (the last change wins).
    function pendingOps() as Lang.Dictionary {
        var ops = get(S_OPS, []) as Lang.Array;
        var d = {};
        for (var i = 0; i < ops.size(); i++) { d[(ops[i] as Lang.Array)[0]] = (ops[i] as Lang.Array)[1]; }
        return d;
    }

    //! Decrypt + merge pulled items, PER_TICK 256-byte blocks per tick.
    var _ms as Lang.Array or Null = null; // page state while merging: [dirty, cur, cnt, names, hexes, ops]
    var _wq as Lang.Array = [];           // page write-back queue: [storage key, value]

    function mergeSome() as Void {
        if (_ms == null) {
            _ms = [get(S_DIRTY, []), get(S_CUR, 0), get(S_CNT, {}), get(S_NAMES, {}), get(S_HEX, {}), pendingOps()];
        }
        var ms = _ms as Lang.Array;
        var dirty = ms[0] as Lang.Array;
        var cur = ms[1];
        var cnt = ms[2] as Lang.Dictionary;
        var names = ms[3] as Lang.Dictionary;
        var hexes = ms[4] as Lang.Dictionary;
        var ops = ms[5] as Lang.Dictionary;
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
            if ("color".equals(kind)) {
                // Items arrive in server (merged) order, so the latest one is the library's.
                var nm = r.get("name");
                var hx = r.get("hex");
                var live = r.get("deleted") != true;
                if (live && nm instanceof Lang.String && (nm as Lang.String).length() > 0) { names[rf] = nm; } else { names.remove(rf); }
                if (live && hx instanceof Lang.String) { hexes[rf] = hx; } else { hexes.remove(rf); }
                continue;
            }
            if (!"highlight".equals(kind)) { continue; } // notes etc. aren't needed on the watch
            // Records the watch wrote: full §3 merge against its copy. Everyone else's: the
            // server's order is the merge order, so the newest item read is current.
            var mine = recGet(id as Lang.String);
            if (mine != null) {
                var c = HwMap.compare(r, text, HwJson.parse(mine as Lang.String) as HwObj, mine as Lang.String);
                if (c < 0) { if (dirty.indexOf(id) < 0) { dirty.add(id); } continue; } // ours is newer: resend
                if (c == 0) { continue; }
                recPut(id as Lang.String, text);
            }
            var e = ixGet(rf);
            var top = HwMap.displayColor(r);
            ixSet(rf, top, HwMap.num(r.get("updated")).toNumber(), cnt);
            if (ops.hasKey(rf)) { continue; } // a local change to this verse is still to be written
            var p = HwMap.split(rf);
            if (p == null) { continue; }
            if (top != null && e == null) { Bookmarks.syncAdd(p[0], p[1], p[2]); }
            if (top == null && e != null) { Bookmarks.syncRemove(p[0], p[1], p[2]); }
        }
        ms[1] = cur;
        if (_queue.size() > 0) { tickSoon(); return; }
        // Page done: queue its writes (shards first, the cursor last) and write them a few per tick.
        _wq = [] as Lang.Array;
        if (_rc != null) {
            for (var i = 0; i < SHARDS; i++) {
                if ((_rcDirty as Lang.Array)[i] == true) { _wq.add([S_REC + i, (_rc as Lang.Array)[i]]); (_rcDirty as Lang.Array)[i] = false; }
            }
        }
        var ks = _ixDirty.keys();
        for (var j = 0; j < ks.size(); j++) { _wq.add([S_IX + ks[j], _ix[ks[j]]]); }
        _ixDirty = {};
        _wq.add([S_DIRTY, dirty]);
        _wq.add([S_CNT, cnt]);
        _wq.add([S_NAMES, names]);
        _wq.add([S_HEX, hexes]);
        _wq.add([S_CUR, cur]);
        _ms = null;
        _phase = :flush;
        tickSoon();
    }

    function flushSome() as Void {
        var n = 0;
        while (n < FLUSH_PER_TICK && _wq.size() > 0) {
            var w = _wq[0] as Lang.Array;
            _wq = _wq.slice(1, null);
            Application.Storage.setValue(w[0] as Lang.String, w[1] as Application.PropertyValueType);
            n++;
        }
        if (_wq.size() > 0) { tickSoon(); return; }
        apply(); // one list write per page
        if (_more) { _phase = :pull; pull(); return; }
        _phase = :edit;
        tickSoon();
    }

    function trimEnd(s as Lang.String) as Lang.String {
        var cs = s.toCharArray();
        var n = cs.size();
        while (n > 0 && cs[n - 1] == ' ') { n--; }
        return s.substring(0, n) as Lang.String;
    }

    //! Remote changes -> the watch's bookmark list (Bookmarks.syncAdd/syncRemove, written here).
    function apply() as Void {
        _applying = true;
        if (Bookmarks.syncFlush()) { WatchUi.requestUpdate(); }
        _applying = false;
    }

    //! Journaled local changes -> highlight records, EDITS_PER_TICK per tick (each parses and
    //! re-serializes a record; a handful in one event trips the watchdog).
    function editSome() as Void {
        var dirty = get(S_DIRTY, []) as Lang.Array;
        var cnt = get(S_CNT, {}) as Lang.Dictionary;
        var ops = get(S_OPS, []) as Lang.Array;
        var now = Time.now().value().toLong();
        var n = 0;
        while (n < EDITS_PER_TICK && ops.size() > 0) {
            var op = ops[0] as Lang.Array;
            ops = ops.slice(1, null);
            var rf = op[0] as Lang.String;
            var on = op[1] as Lang.Boolean;
            var col = op.size() > 2 ? op[2] as Lang.String : null; // recolor (localColor)
            var e = ixGet(rf);
            if (col == null && on && e != null) { continue; } // already highlighted (any color): nothing to add
            if (!on && e == null) { continue; } // nothing live to delete
            var id = itemId("highlight", rf);
            var ot = recGet(id);
            var old = ot == null ? null : HwJson.parse(ot as Lang.String) as HwObj;
            if (old == null && e != null) { // someone else's record: only its `updated` is known
                old = new HwObj().put("kind", "highlight").put("ref", rf).put("updated", (e as Lang.Array)[1]).put("deleted", true);
            }
            var nr = col != null ? HwMap.recolor(old, rf, col, now) : HwMap.edit(old, rf, HwMap.DEFAULT_COLOR, on, now);
            n++;
            recPut(id, HwJson.stringify(nr));
            ixSet(rf, on ? HwMap.displayColor(nr) : null, HwMap.num(nr.get("updated")).toNumber(), cnt);
            if (col != null) { Bookmarks.version++; } // the open Bookmarks list rebuilds with the new color
            if (dirty.indexOf(id) < 0) { dirty.add(id); }
        }
        recFlush();
        ixFlush();
        Application.Storage.setValue(S_OPS, ops);
        Application.Storage.setValue(S_DIRTY, dirty);
        Application.Storage.setValue(S_CNT, cnt);
        if (ops.size() > 0) { tickSoon(); return; }
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
            Perf.log("HWSYNC request too large: " + _post + " items per POST");
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
        Application.Storage.setValue(S_OKAT, Time.now().value());
        summary();
        Perf.log("HWSYNC slices n=" + sliceN + " maxMs=" + sliceMax + " totalMs=" + sliceTotal);
        Perf.log("HWSYNC done ms=" + lastMs + " pulled=" + _stats[0] + " pushed=" + _stats[1] + " skipped=" + _stats[2] + " pages=" + _stats[3] + " big=" + _stats[4]
            + " bookmarks=" + Bookmarks.load().size());
        HwTestSeed.report(get(S_CNT, {}) as Lang.Dictionary, get(S_NAMES, {}) as Lang.Dictionary);
        _phase = :idle;
        finished();
        if (_pending) { _pending = false; _again = false; _keys = null; _keyText = null; start(); return; }
        if (_again) { _again = false; start(); }
    }
}
