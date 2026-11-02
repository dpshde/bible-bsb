using Toybox.Application;
using Toybox.Lang;

//! Compact bookmark store. User-facing word is always "bookmark".
module Bookmarks {
    const STORAGE_KEY = "bookmarks";
    const MAX_DEFAULT = 40;

    //! Pack book:u8 chapter:u8 verse:u8 into a Number.
    //! verse==0 means chapter-level bookmark.
    function pack(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Lang.Number {
        return ((book & 0xFF) << 16) | ((chapter & 0xFF) << 8) | (verse & 0xFF);
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
        var i;
        for (i = 0; i < (v as Lang.Array).size(); i++) {
            var id = (v as Lang.Array)[i];
            if (id instanceof Lang.Number) {
                var b = unpackBook(id);
                var c = unpackChapter(id);
                if (b < Books.BOOK_COUNT && c >= 1 && c <= Books.chapterCount(b) && clean.indexOf(id) < 0) {
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
        version++;
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
        return :added;
    }

    function formatLabel(id as Lang.Number) as Lang.String {
        var b = unpackBook(id);
        var c = unpackChapter(id);
        var v = unpackVerse(id);
        var name = Books.name(b);
        if (v == 0) {
            return name + " " + c;
        }
        return name + " " + c + ":" + v;
    }
}
