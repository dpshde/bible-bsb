using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi as Ui;
import Toybox.Lang;
using Toybox.System;

module BibleError {
    // Error message constants (mirror strings.xml for compile-time safety)
    const MSG_NO_CONNECTION = "No connection";
    const MSG_CHAPTER_NOT_FOUND = "Chapter not found";
    const MSG_LOAD_FAILED = "Failed to load chapter";
    const MSG_COLLECTION_FULL = "Collection full";
    const MSG_NO_PASSAGES = "No saved passages yet.";
    const MSG_UNKNOWN = "(unknown)";
    const MSG_SCAN_WITH_PHONE = "Scan with phone";

    // ------------------------------------------------------------------
    // HTTP response code → user-visible message
    // ------------------------------------------------------------------
    function getErrorMessageForCode(responseCode as Number) as String {
        if (responseCode == 404) {
            return MSG_CHAPTER_NOT_FOUND;
        } else if (responseCode < 0) {
            return MSG_NO_CONNECTION;
        } else if (responseCode >= 400 && responseCode < 600) {
            return MSG_LOAD_FAILED;
        }
        return MSG_LOAD_FAILED;
    }

    // ------------------------------------------------------------------
    // Safe resource string loader: returns fallback if load fails
    // ------------------------------------------------------------------
    function safeLoadString(resourceId as ResourceId, fallback as String) as String {
        try {
            var raw = Ui.loadResource(resourceId);
            if (raw != null) {
                var str = raw as String;
                if (str != null && str.length() > 0) {
                    return str;
                }
            }
        } catch (e) {
            // Resource missing or type mismatch — use fallback
        }
        return fallback;
    }

    // ------------------------------------------------------------------
    // Passage state validation
    // ------------------------------------------------------------------
    function isValidPassageState(state as BibleState or Null) as Boolean {
        if (state == null) {
            return false;
        }
        var bookIndex = state.bookIndex;
        var chapter = state.chapter;
        var startVerse = state.startVerse;
        var endVerse = state.endVerse;

        if (bookIndex < 0 || bookIndex >= BibleBooks.BOOK_COUNT) {
            return false;
        }
        var maxChapter = BibleBooks.getChapterCount(bookIndex);
        if (chapter < 1 || chapter > maxChapter) {
            return false;
        }
        var maxVerse = BibleBooks.getVerseCount(bookIndex, chapter);
        if (maxVerse <= 0) {
            maxVerse = 1;
        }
        if (startVerse < 1 || startVerse > maxVerse) {
            return false;
        }
        if (endVerse < 1 || endVerse > maxVerse) {
            return false;
        }
        if (startVerse > endVerse) {
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------------
    // Safe book index clamping
    // ------------------------------------------------------------------
    function safeBookIndex(index as Number) as Number {
        if (index < 0) {
            return 0;
        }
        if (index >= BibleBooks.BOOK_COUNT) {
            return BibleBooks.BOOK_COUNT - 1;
        }
        return index;
    }

    // ------------------------------------------------------------------
    // Safe chapter clamping for a given book
    // ------------------------------------------------------------------
    function safeChapter(bookIndex as Number, chapter as Number) as Number {
        var safeBook = safeBookIndex(bookIndex);
        var maxChapter = BibleBooks.getChapterCount(safeBook);
        if (maxChapter <= 0) {
            return 1;
        }
        if (chapter < 1) {
            return 1;
        }
        if (chapter > maxChapter) {
            return maxChapter;
        }
        return chapter;
    }

    // ------------------------------------------------------------------
    // Safe verse clamping for a given book/chapter
    // ------------------------------------------------------------------
    function safeVerse(bookIndex as Number, chapter as Number, verse as Number) as Number {
        var safeBook = safeBookIndex(bookIndex);
        var safeCh = safeChapter(safeBook, chapter);
        var maxVerse = BibleBooks.getVerseCount(safeBook, safeCh);
        if (maxVerse <= 0) {
            return 1;
        }
        if (verse < 1) {
            return 1;
        }
        if (verse > maxVerse) {
            return maxVerse;
        }
        return verse;
    }

    // ------------------------------------------------------------------
    // Clamp verse range so start ≤ end and both within bounds
    // ------------------------------------------------------------------
    function clampVerseRange(
        bookIndex as Number,
        chapter as Number,
        startVerse as Number,
        endVerse as Number
    ) as Array<Number> {
        var safeBook = safeBookIndex(bookIndex);
        var safeCh = safeChapter(safeBook, chapter);
        var maxVerse = BibleBooks.getVerseCount(safeBook, safeCh);
        if (maxVerse <= 0) {
            maxVerse = 1;
        }

        var s = startVerse;
        var e = endVerse;
        if (s < 1) {
            s = 1;
        }
        if (s > maxVerse) {
            s = maxVerse;
        }
        if (e < 1) {
            e = 1;
        }
        if (e > maxVerse) {
            e = maxVerse;
        }
        if (e < s) {
            e = s;
        }
        return [s, e] as Array<Number>;
    }

    // ------------------------------------------------------------------
    // Null-safe string extraction from Dictionary
    // ------------------------------------------------------------------
    function safeDictString(dict as Dictionary or Null, key as String, fallback as String) as String {
        if (dict == null) {
            return fallback;
        }
        var raw = dict.get(key);
        if (raw == null) {
            return fallback;
        }
        var str = raw as String;
        if (str == null) {
            return fallback;
        }
        return str.length() > 0 ? str : fallback;
    }

    // ------------------------------------------------------------------
    // Null-safe Number extraction from Dictionary
    // ------------------------------------------------------------------
    function safeDictNumber(dict as Dictionary or Null, key as String, fallback as Number) as Number {
        if (dict == null) {
            return fallback;
        }
        var raw = dict.get(key);
        if (raw == null) {
            return fallback;
        }
        var num = raw as Number;
        if (num == null) {
            return fallback;
        }
        return num;
    }

    // ------------------------------------------------------------------
    // Null-safe Boolean extraction from Dictionary
    // ------------------------------------------------------------------
    function safeDictBoolean(dict as Dictionary or Null, key as String, fallback as Boolean) as Boolean {
        if (dict == null) {
            return fallback;
        }
        var raw = dict.get(key);
        if (raw == null) {
            return fallback;
        }
        var b = raw as Boolean;
        if (b == null) {
            return fallback;
        }
        return b;
    }

    // ------------------------------------------------------------------
    // Collection storage validation
    // ------------------------------------------------------------------
    function isValidCollectionEntry(entry as Dictionary or Null) as Boolean {
        if (entry == null) {
            return false;
        }
        var ref = entry.get("scripture_ref");
        if (ref == null) {
            return false;
        }
        var refStr = ref as String;
        if (refStr == null || refStr.length() == 0) {
            return false;
        }
        var bookIndex = entry.get("book_index");
        if (bookIndex == null) {
            return false;
        }
        var bi = bookIndex as Number;
        if (bi == null || bi < 0 || bi >= BibleBooks.BOOK_COUNT) {
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------------
    // Safe collection entry builder that fills missing fields with defaults
    // ------------------------------------------------------------------
    function safeCollectionEntry(source as Dictionary or Null) as Dictionary {
        var entry = {} as Dictionary;
        var ref = safeDictString(source, "scripture_ref", "");
        if (ref.length() == 0) {
            ref = "unk.1.1";
        }
        entry.put("scripture_ref", ref);
        entry.put("display_ref", safeDictString(source, "display_ref", ref));
        entry.put("translation", safeDictString(source, "translation", "BSB"));
        entry.put("book_index", safeDictNumber(source, "book_index", 0));
        entry.put("chapter", safeDictNumber(source, "chapter", 1));
        entry.put("start_verse", safeDictNumber(source, "start_verse", 1));
        entry.put("end_verse", safeDictNumber(source, "end_verse", 1));
        entry.put("captured_at", safeDictString(source, "captured_at", "1970-01-01T00:00:00Z"));
        return entry;
    }

    // ------------------------------------------------------------------
    // Check if collection is at max capacity
    // ------------------------------------------------------------------
    function isCollectionFull() as Boolean {
        return BibleStorage.getCount() >= BibleStorage.MAX_ENTRIES;
    }

    // ------------------------------------------------------------------
    // Safe Application.Storage read that never crashes on null/empty
    // ------------------------------------------------------------------
    function safeStorageGet(key as String) as Array<Dictionary> {
        try {
            var raw = Application.Storage.getValue(key);
            if (raw == null || !(raw instanceof Array)) {
                return [] as Array<Dictionary>;
            }
            var arr = raw as Array;
            var result = [] as Array<Dictionary>;
            for (var i = 0; i < arr.size(); i++) {
                var item = arr[i];
                if (item != null && item instanceof Dictionary) {
                    result.add(item as Dictionary);
                }
            }
            return result;
        } catch (e) {
            // Storage read failed — return empty array
            return [] as Array<Dictionary>;
        }
    }

    // ------------------------------------------------------------------
    // Safe Application.Storage write that handles null collection
    // ------------------------------------------------------------------
    function safeStorageSet(key as String, collection as Array<Dictionary>) as Boolean {
        try {
            if (collection == null) {
                collection = [] as Array<Dictionary>;
            }
            Application.Storage.setValue(key, collection as Application.Storage.ValueType);
            return true;
        } catch (e) {
            // Storage write failed (possibly full)
            return false;
        }
    }

    // ------------------------------------------------------------------
    // Validate a loaded verse array isn't empty/corrupt
    // ------------------------------------------------------------------
    function isValidVerseArray(verses as Array<Dictionary> or Null) as Boolean {
        if (verses == null || verses.size() == 0) {
            return false;
        }
        var first = verses[0] as Dictionary;
        if (first == null) {
            return false;
        }
        var num = first.get("verseNumber");
        var text = first.get("verseText");
        if (num == null || text == null) {
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------------
    // Safe layout computation: returns a minimal valid layout even if DC is null
    // ------------------------------------------------------------------
    function safeComputeLayout(dc as Graphics.Dc or Null) as Dictionary {
        if (dc == null) {
            // Return a minimal fallback layout for 176x176
            return BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        }
        return BibleLayout.computeLayout(dc);
    }

    // ------------------------------------------------------------------
    // Safe array size that handles null
    // ------------------------------------------------------------------
    function safeArraySize(arr as Object or Null) as Number {
        if (arr == null || !(arr instanceof Array)) {
            return 0;
        }
        var a = arr as Array;
        return a.size();
    }

    // ------------------------------------------------------------------
    // Toast helper with safe defaults
    // ------------------------------------------------------------------
    function showToast(state as BibleState, message as String, durationMs as Number) as Void {
        if (state == null || message == null || message.length() == 0) {
            return;
        }
        state.readerToastMessage = message;
        state.readerToastEndTime = System.getTimer() + durationMs;
    }
}
