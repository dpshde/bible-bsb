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

    function load() as Lang.Array {
        var v = Application.Storage.getValue(STORAGE_KEY);
        if (v == null || !(v instanceof Lang.Array)) {
            return [];
        }
        return v as Lang.Array;
    }

    function save(list as Lang.Array) as Void {
        Application.Storage.setValue(STORAGE_KEY, list);
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
