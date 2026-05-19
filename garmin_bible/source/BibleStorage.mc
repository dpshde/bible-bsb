using Toybox.Application;
import Toybox.Lang;
using Toybox.System;

class BibleStorage {
    static const COLLECTION_KEY = "collection";
    static const MAX_ENTRIES = 50;

    // Save a passage entry. Returns true if saved, false if duplicate.
    static function saveEntry(entry as Dictionary) as Boolean {
        var raw = Application.Storage.getValue(COLLECTION_KEY);
        var count = 0;
        var isDuplicate = false;
        var ref = entry.get("scripture_ref") as String;

        if (raw != null && raw instanceof Dictionary) {
            var storedDict = raw as Dictionary;
            var countVal = storedDict.get("count");
            if (countVal != null) {
                count = countVal as Number;
            }
            for (var i = 0; i < count; i++) {
                var key = "entry_" + i;
                var e = storedDict.get(key);
                if (e != null && e instanceof Dictionary) {
                    var ed = e as Dictionary;
                    var existingRef = ed.get("scripture_ref") as String;
                    if (existingRef != null && existingRef == ref) {
                        isDuplicate = true;
                        break;
                    }
                }
            }

            if (isDuplicate) {
                return false;
            }

            if (count >= MAX_ENTRIES) {
                var newDict = {} as Dictionary;
                newDict.put("count", MAX_ENTRIES - 1);
                for (var i = 1; i < count; i++) {
                    var oldKey = "entry_" + i;
                    var newKey = "entry_" + (i - 1);
                    var val = storedDict.get(oldKey);
                    if (val != null) {
                        newDict.put(newKey, val);
                    }
                }
                newDict.put("entry_" + (MAX_ENTRIES - 1), entry);
                Application.Storage.setValue(COLLECTION_KEY, newDict as Application.Storage.ValueType);
            } else {
                storedDict.put("count", count + 1);
                storedDict.put("entry_" + count, entry);
                Application.Storage.setValue(COLLECTION_KEY, storedDict as Application.Storage.ValueType);
            }
            return true;
        }

        // No existing collection — create new
        var newDict = {} as Dictionary;
        newDict.put("count", 1);
        newDict.put("entry_0", entry);
        Application.Storage.setValue(COLLECTION_KEY, newDict as Application.Storage.ValueType);
        return true;
    }

    // Load all collection entries as an Array of Dictionaries
    static function loadAll() as Array<Dictionary> {
        var raw = Application.Storage.getValue(COLLECTION_KEY);
        var result = [] as Array<Dictionary>;
        if (raw != null && raw instanceof Dictionary) {
            var storedDict = raw as Dictionary;
            var countVal = storedDict.get("count");
            var count = 0;
            if (countVal != null) {
                count = countVal as Number;
            }
            for (var i = 0; i < count; i++) {
                var key = "entry_" + i;
                var e = storedDict.get(key);
                if (e != null && e instanceof Dictionary) {
                    result.add(e as Dictionary);
                }
            }
        }
        return result;
    }

    // Get the count of saved entries
    static function getCount() as Number {
        var raw = Application.Storage.getValue(COLLECTION_KEY);
        if (raw != null && raw instanceof Dictionary) {
            var storedDict = raw as Dictionary;
            var countVal = storedDict.get("count");
            if (countVal != null) {
                return countVal as Number;
            }
        }
        return 0;
    }

    // Delete an entry by index
    static function deleteEntry(index as Number) as Boolean {
        var raw = Application.Storage.getValue(COLLECTION_KEY);
        if (raw == null || !(raw instanceof Dictionary)) {
            return false;
        }
        var storedDict = raw as Dictionary;
        var countVal = storedDict.get("count");
        var count = 0;
        if (countVal != null) {
            count = countVal as Number;
        }
        if (index < 0 || index >= count) {
            return false;
        }

        var newDict = {} as Dictionary;
        var newCount = count - 1;
        newDict.put("count", newCount);
        var j = 0;
        for (var i = 0; i < count; i++) {
            if (i != index) {
                var oldKey = "entry_" + i;
                var newKey = "entry_" + j;
                var val = storedDict.get(oldKey);
                if (val != null) {
                    newDict.put(newKey, val);
                }
                j = j + 1;
            }
        }
        Application.Storage.setValue(COLLECTION_KEY, newDict as Application.Storage.ValueType);
        return true;
    }
}
