using Toybox.Application;
import Toybox.Lang;
using Toybox.System;
using Toybox.Time;

class BibleStorage {
    static const COLLECTION_KEY = "collection";
    static const MAX_ENTRIES = 50;
    static const TRANSLATION = "BSB";

    // Build a collection entry from current passage state.
    // Entry fields: scripture_ref, display_ref, translation, book_index,
    // chapter, start_verse, end_verse, captured_at.
    static function buildEntry(state as BibleState) as Dictionary {
        var entry = {} as Dictionary;
        entry.put("scripture_ref", state.getScriptureRef());
        entry.put("display_ref", state.getDisplayRef());
        entry.put("translation", TRANSLATION);
        entry.put("book_index", state.bookIndex);
        entry.put("chapter", state.chapter);
        entry.put("start_verse", state.startVerse);
        entry.put("end_verse", state.endVerse);
        entry.put("captured_at", getIsoTimestamp());
        return entry;
    }

    // Save an entry to Storage. Returns true if saved, false if duplicate or invalid.
    static function saveEntry(entry as Dictionary) as Boolean {
        if (entry == null) {
            return false;
        }

        // Validate entry has minimum required fields
        if (!BibleError.isValidCollectionEntry(entry)) {
            // Attempt to sanitize the entry
            entry = BibleError.safeCollectionEntry(entry);
        }

        var collection = loadAll();
        var ref = entry.get("scripture_ref") as String;
        if (ref == null) {
            ref = "";
        }

        // Check for duplicate by scripture_ref
        for (var i = 0; i < collection.size(); i++) {
            var existing = collection[i] as Dictionary;
            if (existing == null) {
                continue;
            }
            var existingRef = existing.get("scripture_ref") as String;
            if (existingRef != null && existingRef.equals(ref)) {
                return false;
            }
        }

        // FIFO: if at max, remove oldest entry (index 0)
        if (collection.size() >= MAX_ENTRIES) {
            if (collection.size() > 0) {
                collection.remove(collection[0]);
            }
        }

        collection.add(entry);
        var saved = BibleError.safeStorageSet(COLLECTION_KEY, collection);
        return saved;
    }

    // Load all collection entries as Array<Dictionary>.
    // Oldest entry is at index 0; newest at index size-1.
    // Uses safeStorageGet for defensive null handling.
    static function loadAll() as Array<Dictionary> {
        return BibleError.safeStorageGet(COLLECTION_KEY);
    }

    // Load a single entry by storage index.
    // Returns null if index is out of bounds.
    static function loadEntry(index as Number) as Dictionary? {
        var collection = loadAll();
        if (index < 0 || index >= collection.size()) {
            return null;
        }
        return collection[index];
    }

    // Get the count of saved entries.
    static function getCount() as Number {
        return loadAll().size();
    }

    // Delete an entry by storage index.
    // Returns true if deleted, false if index was out of bounds.
    static function deleteEntry(index as Number) as Boolean {
        var collection = loadAll();
        if (index < 0 || index >= collection.size()) {
            return false;
        }
        collection.remove(collection[index]);
        Application.Storage.setValue(COLLECTION_KEY, collection as Application.Storage.ValueType);
        return true;
    }

    // Clear all collection entries.
    static function clearAll() as Void {
        Application.Storage.setValue(COLLECTION_KEY, [] as Application.Storage.ValueType);
    }

    // Format current UTC time as ISO8601 timestamp: YYYY-MM-DDTHH:MM:SSZ
    private static function getIsoTimestamp() as String {
        var moment = Time.now();
        var info = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
        var year = info.year as Number;
        var month = info.month as Number;
        var day = info.day as Number;
        var hour = info.hour as Number;
        var min = info.min as Number;
        var sec = info.sec as Number;
        return year.toString() + "-" + pad2(month) + "-" + pad2(day)
            + "T" + pad2(hour) + ":" + pad2(min) + ":" + pad2(sec) + "Z";
    }

    // Zero-pad a number to two digits.
    private static function pad2(n as Number) as String {
        if (n < 10) {
            return "0" + n;
        }
        return n.toString();
    }
}
