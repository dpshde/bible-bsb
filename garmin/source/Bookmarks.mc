using Toybox.Application;
using Toybox.Lang;

//! Compact bookmark store. User-facing word is always "bookmark".
module Bookmarks {
    const STORAGE_KEY = "bookmarks";
    // POKE: BOOKMARKS_MAX — Hidden Word sync brings every highlight onto the list, so the cap
    // is sized for large libraries: 3,500 packed Numbers are ~18 KB in one Storage value (32 KB cap).
    const MAX_DEFAULT = 3500;

    //! v9: a bookmark is book/chapter/startVerse/endVerse packed into one Number:
    //! end:u8 << 24 | book:u8 << 16 | chapter:u8 << 8 | start:u8. end byte 0 = single verse, so every
    //! pre-v9 id (single verse or chapter, top byte 0) already reads as endVerse == startVerse —
    //! saved bookmarks migrate without a rewrite. Ranges stay inside one chapter (Flipper's model).
    //! verse==0 means chapter-level bookmark.
    function pack(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Lang.Number {
        return ((book & 0xFF) << 16) | ((chapter & 0xFF) << 8) | (verse & 0xFF);
    }

    function packRange(book as Lang.Number, chapter as Lang.Number, start as Lang.Number,
                       end as Lang.Number) as Lang.Number {
        var id = pack(book, chapter, start);
        if (start > 0 && end > start) {
            id = id | ((end & 0xFF) << 24);
        }
        return id;
    }

    //! Last verse of the bookmark (== start verse for single-verse and pre-v9 bookmarks).
    function unpackEnd(id as Lang.Number) as Lang.Number {
        var s = unpackVerse(id);
        var e = (id >> 24) & 0xFF;
        return e > s ? e : s;
    }

    function isRange(id as Lang.Number) as Lang.Boolean {
        return unpackEnd(id) > unpackVerse(id);
    }

    function unpackBook(id as Lang.Number) as Lang.Number {
        return (id >> 16) & 0xFF;
    }

    function unpackChapter(id as Lang.Number) as Lang.Number {
        return (id >> 8) & 0xFF;
    }

    function unpackVerse(id as Lang.Number) as Lang.Number {
        return id & 0xFF;
    }

    // PERF: Storage is flash on device — read once, then serve from memory.
    var _cache as Lang.Array or Null = null;
    var version as Lang.Number = 0; // bumps on every save (reader tick cache key)

    function load() as Lang.Array {
        if (_cache != null) {
            return _cache as Lang.Array;
        }
        var v = Application.Storage.getValue(STORAGE_KEY);
        if (v == null || !(v instanceof Lang.Array)) {
            v = [];
        }
        // Corrupt / old data: keep only packed ids that decode to a real book + chapter.
        var clean = [] as Lang.Array;
        var seen = {}; // dictionary dedupe: synced lists hold thousands of ids
        var i;
        for (i = 0; i < (v as Lang.Array).size(); i++) {
            var id = (v as Lang.Array)[i];
            if (id instanceof Lang.Number) {
                // Normalize: a stray end byte <= start (never written) reads as a single verse.
                if (((id >> 24) & 0xFF) != 0 && !isRange(id)) {
                    id = id & 0xFFFFFF;
                }
                var b = unpackBook(id);
                var c = unpackChapter(id);
                if (b < Books.BOOK_COUNT && c >= 1 && c <= Books.chapterCount(b) && !seen.hasKey(id)) {
                    seen[id] = true;
                    clean.add(id);
                }
            }
        }
        _cache = clean;
        return _cache as Lang.Array;
    }

    function save(list as Lang.Array) as Void {
        Application.Storage.setValue(STORAGE_KEY, list);
        _cache = list;
        _cover = null;
        version++;
    }

    // ---- Changes from Hidden Word sync (single verses; never journaled back) -----------------
    var _cover as Lang.Dictionary or Null = null; // packed single-verse id -> true, every verse the list covers
    var _adds as Lang.Array = [];
    var _changed as Lang.Boolean = false;

    function cover() as Lang.Dictionary {
        if (_cover == null) {
            var d = {};
            var list = load();
            for (var i = 0; i < list.size(); i++) {
                var id = list[i] as Lang.Number;
                var s = unpackVerse(id);
                if (s <= 0) { continue; }
                for (var v = s; v <= unpackEnd(id); v++) { d[pack(unpackBook(id), unpackChapter(id), v)] = true; }
            }
            _cover = d;
        }
        return _cover as Lang.Dictionary;
    }

    //! A synced highlight: add the verse unless a bookmark already covers it (or the list is full).
    function syncAdd(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Void {
        var id = pack(book, chapter, verse);
        var c = cover();
        if (c.hasKey(id) || load().size() + _adds.size() >= MAX_DEFAULT) { return; }
        c[id] = true;
        _adds.add(id);
    }

    //! A highlight deleted elsewhere: the verse leaves the list (a range around it splits).
    function syncRemove(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Void {
        var id = pack(book, chapter, verse);
        var c = cover();
        if (!c.hasKey(id)) { return; }
        c.remove(id);
        if (_adds.indexOf(id) >= 0) { _adds.remove(id); return; }
        var list = load();
        if (list.indexOf(id) >= 0) { list.remove(id); _changed = true; return; }
        for (var i = 0; i < list.size(); i++) {
            var r = list[i] as Lang.Number;
            if (!isRange(r) || unpackBook(r) != book || unpackChapter(r) != chapter) { continue; }
            var s = unpackVerse(r);
            var e = unpackEnd(r);
            if (verse < s || verse > e) { continue; }
            var parts = [] as Lang.Array;
            if (verse > s) { parts.add(packRange(book, chapter, s, verse - 1)); }
            if (verse < e) { parts.add(packRange(book, chapter, verse + 1, e)); }
            var next = list.slice(0, i);
            next.addAll(parts);
            next.addAll(list.slice(i + 1, null));
            _cache = next;
            _changed = true;
            return;
        }
    }

    //! Write the synced changes (newest additions first). True when the list changed.
    function syncFlush() as Lang.Boolean {
        if (_adds.size() == 0 && !_changed) { return false; }
        var next = [] as Lang.Array;
        for (var i = _adds.size() - 1; i >= 0; i--) { next.add(_adds[i]); }
        next.addAll(load());
        var c = _cover;
        save(next);
        _cover = c;
        _adds = [];
        _changed = false;
        return true;
    }

    //! Toggle: remove if present, else prepend. Returns :added, :removed, or :full.
    function toggle(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Lang.Symbol {
        // POKE: per-device maxCount from device memory class.
        var maxCount = MAX_DEFAULT;
        var id = pack(book, chapter, verse);
        var list = load();
        var i = 0;
        for (i = 0; i < list.size(); i++) {
            if (list[i] == id) {
                list.remove(list[i]);
                save(list);
                HwSync.local(id, false);
                HwSync.changed();
                return :removed;
            }
        }
        if (list.size() >= maxCount) {
            return :full;
        }
        var next = [id];
        for (i = 0; i < list.size(); i++) {
            next.add(list[i]);
        }
        save(next);
        HwSync.local(id, true);
        HwSync.changed();
        return :added;
    }

    //! v9: save a verse range (start == end saves a single verse). :added, :exists, or :full.
    function addRange(book as Lang.Number, chapter as Lang.Number, start as Lang.Number,
                      end as Lang.Number) as Lang.Symbol {
        if (end < start) {
            var t = start;
            start = end;
            end = t;
        }
        var id = packRange(book, chapter, start, end);
        var list = load();
        if (list.indexOf(id) >= 0) {
            return :exists;
        }
        if (list.size() >= MAX_DEFAULT) {
            return :full;
        }
        var next = [id];
        var i;
        for (i = 0; i < list.size(); i++) {
            next.add(list[i]);
        }
        save(next);
        HwSync.local(id, true);
        HwSync.changed();
        return :added;
    }

    function remove(id as Lang.Number) as Void {
        var list = load();
        var i = list.indexOf(id);
        if (i >= 0) {
            list.remove(list[i]);
            save(list);
            HwSync.local(id, false);
            HwSync.changed();
        }
    }

    // ---- Display rows: verse ranges merged at display time (Hidden Word web, SPEC 1.2) ---------
    // Storage is unchanged (one id per bookmark; synced highlights are one id per verse). The list
    // shows a run of verses that are consecutive, same book, same chapter and same color as one
    // row ("Psalms 23:1–4"); a gap, a color change or a chapter change starts a new row. Colors:
    // packed single-verse id -> color id (HwSync.colorIds, HwMap.displayColor); null = no colors
    // (merge on adjacency only). Rows come out newest first (by their newest verse), as packed
    // range ids (packRange), at most `max`. Chapter bookmarks (verse 0) stay their own rows.
    function mergeRows(ids as Lang.Array, colors as Lang.Dictionary or Null, max as Lang.Number) as Lang.Array {
        var have = {};
        var i;
        for (i = 0; i < ids.size(); i++) {
            var id = ids[i] as Lang.Number;
            var s = unpackVerse(id);
            if (s <= 0) { continue; }
            var base = id & 0xFFFF00;
            for (var v = s; v <= unpackEnd(id); v++) { have[base | v] = true; }
        }
        var used = {};
        var out = [] as Lang.Array;
        for (i = 0; i < ids.size() && out.size() < max; i++) {
            var id = ids[i] as Lang.Number;
            var s = unpackVerse(id);
            if (s <= 0) {
                if (!used.hasKey(id)) { used[id] = true; out.add(id); }
                continue;
            }
            var base = id & 0xFFFF00;
            for (var v = s; v <= unpackEnd(id) && out.size() < max; v++) {
                if (used.hasKey(base | v)) { continue; }
                var col = colors != null ? (colors as Lang.Dictionary)[base | v] : null;
                var lo = v;
                while (lo > 1 && have.hasKey(base | (lo - 1)) && !used.hasKey(base | (lo - 1))
                       && sameColor(colors, base | (lo - 1), col)) { lo--; }
                var hi = v;
                while (hi < 255 && have.hasKey(base | (hi + 1)) && !used.hasKey(base | (hi + 1))
                       && sameColor(colors, base | (hi + 1), col)) { hi++; }
                for (var k = lo; k <= hi; k++) { used[base | k] = true; }
                out.add(base | lo | (hi > lo ? (hi << 24) : 0));
            }
        }
        return out;
    }

    function sameColor(colors as Lang.Dictionary or Null, id as Lang.Number, col) as Lang.Boolean {
        if (colors == null) { return true; }
        var c = (colors as Lang.Dictionary)[id];
        return c == null ? col == null : (col != null && c.equals(col));
    }

    //! The single verses of rows (packed ids), in row order, verses ascending.
    function verses(rows as Lang.Array) as Lang.Array {
        var out = [] as Lang.Array;
        for (var i = 0; i < rows.size(); i++) {
            var id = rows[i] as Lang.Number;
            var s = unpackVerse(id);
            if (s <= 0) { out.add(id); continue; }
            for (var v = s; v <= unpackEnd(id); v++) { out.add((id & 0xFFFF00) | v); }
        }
        return out;
    }

    //! Is this single verse on the list (as itself or inside a stored range)?
    function hasVerse(id as Lang.Number) as Lang.Boolean {
        return cover().hasKey(id & 0xFFFFFF);
    }

    //! Delete ONE verse (Bookmarks > merged row > verse > Delete): that verse leaves the list (a
    //! stored range around it splits) and only its record is journaled (tombstone on sync).
    function removeVerse(id as Lang.Number) as Void {
        id = id & 0xFFFFFF;
        var list = load();
        var next = [] as Lang.Array;
        var hit = false;
        for (var i = 0; i < list.size(); i++) {
            var r = list[i] as Lang.Number;
            var s = unpackVerse(r);
            var v = unpackVerse(id);
            if (s > 0 && (r & 0xFFFF00) == (id & 0xFFFF00) && v >= s && v <= unpackEnd(r)) {
                hit = true;
                var b = unpackBook(r);
                var c = unpackChapter(r);
                if (v > s) { next.add(packRange(b, c, s, v - 1)); }
                if (v < unpackEnd(r)) { next.add(packRange(b, c, v + 1, unpackEnd(r))); }
                continue;
            }
            next.add(r);
        }
        if (!hit) { return; }
        save(next);
        HwSync.local(id, false);
        HwSync.changed();
    }

    //! Recolor ONE verse: only its record is rewritten (HwMap.recolor on sync).
    function recolorVerse(id as Lang.Number, color as Lang.String) as Void {
        HwSync.localColor(id & 0xFFFFFF, color);
        HwSync.changed();
    }

    //! "John 3:16", "Genesis 1:1–3" (en dash), "Psalms 119".
    function formatLabel(id as Lang.Number) as Lang.String {
        var b = unpackBook(id);
        var c = unpackChapter(id);
        var v = unpackVerse(id);
        var name = Books.name(b);
        if (v == 0) {
            return name + " " + c;
        }
        var e = unpackEnd(id);
        return name + " " + c + ":" + v + (e > v ? "–" + e : "");
    }
}
