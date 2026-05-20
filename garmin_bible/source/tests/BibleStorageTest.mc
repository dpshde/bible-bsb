import Toybox.Lang;
using Toybox.Test;
using Toybox.Application;

class BibleStorageTest {

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private function makeTestState(bookIndex as Number, chapter as Number,
                                   startVerse as Number, endVerse as Number) as BibleState {
        var state = new BibleState();
        state.bookIndex = bookIndex;
        state.chapter = chapter;
        state.startVerse = startVerse;
        state.endVerse = endVerse;
        return state;
    }

    private function makeTestEntry(ref as String, display as String) as Dictionary {
        var entry = {} as Dictionary;
        entry.put("scripture_ref", ref);
        entry.put("display_ref", display);
        entry.put("translation", "BSB");
        entry.put("book_index", 42);
        entry.put("chapter", 3);
        entry.put("start_verse", 16);
        entry.put("end_verse", 16);
        entry.put("captured_at", "2025-01-01T12:00:00Z");
        return entry;
    }

    private function clearStorage() as Void {
        Application.Storage.setValue(BibleStorage.COLLECTION_KEY,
            [] as Application.Storage.ValueType);
    }

    // -----------------------------------------------------------------------
    // buildEntry tests
    // -----------------------------------------------------------------------

    function testBuildEntryHasAllFields(logger as Test.Logger) as Boolean {
        var state = makeTestState(42, 3, 16, 16); // John 3:16
        var entry = BibleStorage.buildEntry(state);

        if (entry == null) {
            return false;
        }
        var requiredKeys = [
            "scripture_ref", "display_ref", "translation",
            "book_index", "chapter", "start_verse", "end_verse", "captured_at"
        ];
        for (var i = 0; i < requiredKeys.size(); i++) {
            if (entry.get(requiredKeys[i]) == null) {
                return false;
            }
        }
        return true;
    }

    function testBuildEntrySingleVerseRefs(logger as Test.Logger) as Boolean {
        var state = makeTestState(42, 3, 16, 16); // John 3:16
        var entry = BibleStorage.buildEntry(state);
        var scriptureRef = entry.get("scripture_ref") as String;
        var displayRef = entry.get("display_ref") as String;
        return scriptureRef == "jhn.3.16" && displayRef == "John 3:16";
    }

    function testBuildEntryRangeRefs(logger as Test.Logger) as Boolean {
        var state = makeTestState(42, 3, 16, 18); // John 3:16-18
        var entry = BibleStorage.buildEntry(state);
        var scriptureRef = entry.get("scripture_ref") as String;
        var displayRef = entry.get("display_ref") as String;
        return scriptureRef == "jhn.3.16-jhn.3.18" && displayRef == "John 3:16-18";
    }

    function testBuildEntryFullChapterRefs(logger as Test.Logger) as Boolean {
        var state = makeTestState(42, 3, 1, 36); // John 3 (full chapter)
        var entry = BibleStorage.buildEntry(state);
        var displayRef = entry.get("display_ref") as String;
        return displayRef == "John 3";
    }

    function testBuildEntryCapturedAtIsIsoTimestamp(logger as Test.Logger) as Boolean {
        var state = makeTestState(42, 3, 16, 16);
        var entry = BibleStorage.buildEntry(state);
        var ts = entry.get("captured_at") as String;
        if (ts == null || ts.length() == 0) {
            return false;
        }
        // ISO8601 pattern: YYYY-MM-DDTHH:MM:SSZ
        // Check for T separator and trailing Z
        var tIndex = -1;
        for (var i = 0; i < ts.length(); i++) {
            var ch = ts.substring(i, i + 1);
            if (ch != null && ch == "T") {
                tIndex = i;
                break;
            }
        }
        var zIndex = -1;
        for (var i = 0; i < ts.length(); i++) {
            var ch = ts.substring(i, i + 1);
            if (ch != null && ch == "Z") {
                zIndex = i;
                break;
            }
        }
        return tIndex > 0 && zIndex > tIndex;
    }

    function testBuildEntryTranslationIsBsb(logger as Test.Logger) as Boolean {
        var state = makeTestState(42, 3, 16, 16);
        var entry = BibleStorage.buildEntry(state);
        var translation = entry.get("translation") as String;
        return translation == "BSB";
    }

    // -----------------------------------------------------------------------
    // Save / load round-trip tests
    // -----------------------------------------------------------------------

    function testSaveAndLoadRoundTrip(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeTestEntry("gen.1.1", "Genesis 1:1");
        var saved = BibleStorage.saveEntry(entry);
        if (saved != BibleStorage.SAVE_STATUS_SAVED) {
            return false;
        }
        var loaded = BibleStorage.loadAll();
        if (loaded.size() != 1) {
            return false;
        }
        var first = loaded[0] as Dictionary;
        var ref = first.get("scripture_ref") as String;
        return ref == "gen.1.1";
    }

    function testLoadEntryByIndex(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry1 = makeTestEntry("gen.1.1", "Genesis 1:1");
        var entry2 = makeTestEntry("jhn.3.16", "John 3:16");
        BibleStorage.saveEntry(entry1);
        BibleStorage.saveEntry(entry2);

        var loaded0 = BibleStorage.loadEntry(0);
        var loaded1 = BibleStorage.loadEntry(1);
        if (loaded0 == null || loaded1 == null) {
            return false;
        }
        var ref0 = loaded0.get("scripture_ref") as String;
        var ref1 = loaded1.get("scripture_ref") as String;
        return ref0 == "gen.1.1" && ref1 == "jhn.3.16";
    }

    function testLoadEntryOutOfBounds(logger as Test.Logger) as Boolean {
        clearStorage();
        var loaded = BibleStorage.loadEntry(0);
        return loaded == null;
    }

    function testLoadAllEmptyCollection(logger as Test.Logger) as Boolean {
        clearStorage();
        var loaded = BibleStorage.loadAll();
        return loaded != null && loaded.size() == 0;
    }

    // -----------------------------------------------------------------------
    // Duplicate detection
    // -----------------------------------------------------------------------

    function testDuplicateSaveRejected(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeTestEntry("jhn.3.16", "John 3:16");
        var saved1 = BibleStorage.saveEntry(entry);
        var saved2 = BibleStorage.saveEntry(entry);
        return saved1 == BibleStorage.SAVE_STATUS_SAVED
            && saved2 == BibleStorage.SAVE_STATUS_DUPLICATE
            && BibleStorage.getCount() == 1;
    }

    function testDuplicateByRefOnly(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry1 = makeTestEntry("jhn.3.16", "John 3:16");
        var entry2 = makeTestEntry("jhn.3.16", "John 3:16-18"); // same ref, different display
        BibleStorage.saveEntry(entry1);
        var saved2 = BibleStorage.saveEntry(entry2);
        return saved2 == BibleStorage.SAVE_STATUS_DUPLICATE && BibleStorage.getCount() == 1;
    }

    // -----------------------------------------------------------------------
    // Size limit and FIFO tests
    // -----------------------------------------------------------------------

    function testMaxEntriesEnforced(logger as Test.Logger) as Boolean {
        clearStorage();
        for (var i = 0; i < BibleStorage.MAX_ENTRIES + 5; i++) {
            var entry = makeTestEntry("ref." + i + ".1", "Ref " + i + ":1");
            BibleStorage.saveEntry(entry);
        }
        var count = BibleStorage.getCount();
        return count == BibleStorage.MAX_ENTRIES;
    }

    function testFifoOldestReplaced(logger as Test.Logger) as Boolean {
        clearStorage();
        var firstEntry = makeTestEntry("gen.1.1", "Genesis 1:1");
        BibleStorage.saveEntry(firstEntry);

        for (var i = 0; i < BibleStorage.MAX_ENTRIES - 1; i++) {
            var entry = makeTestEntry("ref." + i + ".1", "Ref " + i + ":1");
            BibleStorage.saveEntry(entry);
        }

        // Collection is now full; adding one more should evict oldest (gen.1.1)
        var overflow = makeTestEntry("rev.22.21", "Revelation 22:21");
        BibleStorage.saveEntry(overflow);

        var loaded = BibleStorage.loadAll();
        if (loaded.size() != BibleStorage.MAX_ENTRIES) {
            return false;
        }

        // Verify the oldest entry (gen.1.1) is gone
        var foundOld = false;
        for (var i = 0; i < loaded.size(); i++) {
            var e = loaded[i] as Dictionary;
            var ref = e.get("scripture_ref") as String;
            if (ref == "gen.1.1") {
                foundOld = true;
                break;
            }
        }

        // Verify the newest entry is present
        var foundNew = false;
        for (var i = 0; i < loaded.size(); i++) {
            var e = loaded[i] as Dictionary;
            var ref = e.get("scripture_ref") as String;
            if (ref == "rev.22.21") {
                foundNew = true;
                break;
            }
        }

        return !foundOld && foundNew;
    }

    function testFifoPreservesMiddleEntries(logger as Test.Logger) as Boolean {
        clearStorage();
        var middleRef = "mid.5.5";

        for (var i = 0; i < BibleStorage.MAX_ENTRIES; i++) {
            var ref = (i == 5) ? middleRef : ("ref." + i + ".1");
            var entry = makeTestEntry(ref, "Ref " + i + ":1");
            BibleStorage.saveEntry(entry);
        }

        // Overflow once
        var overflow = makeTestEntry("overflow.1.1", "Overflow 1:1");
        BibleStorage.saveEntry(overflow);

        // Verify middle entry still exists
        var loaded = BibleStorage.loadAll();
        var foundMiddle = false;
        for (var i = 0; i < loaded.size(); i++) {
            var e = loaded[i] as Dictionary;
            var ref = e.get("scripture_ref") as String;
            if (ref == middleRef) {
                foundMiddle = true;
                break;
            }
        }
        return foundMiddle;
    }

    // -----------------------------------------------------------------------
    // Delete tests
    // -----------------------------------------------------------------------

    function testDeleteRemovesEntry(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry1 = makeTestEntry("gen.1.1", "Genesis 1:1");
        var entry2 = makeTestEntry("jhn.3.16", "John 3:16");
        BibleStorage.saveEntry(entry1);
        BibleStorage.saveEntry(entry2);

        var deleted = BibleStorage.deleteEntry(0);
        if (!deleted) {
            return false;
        }

        var loaded = BibleStorage.loadAll();
        if (loaded.size() != 1) {
            return false;
        }
        var first = loaded[0] as Dictionary;
        var ref = first.get("scripture_ref") as String;
        return ref == "jhn.3.16";
    }

    function testDeleteUpdatesStorage(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeTestEntry("gen.1.1", "Genesis 1:1"));
        BibleStorage.saveEntry(makeTestEntry("jhn.3.16", "John 3:16"));
        BibleStorage.deleteEntry(0);

        // Verify via raw Storage read
        var raw = Application.Storage.getValue(BibleStorage.COLLECTION_KEY);
        if (raw == null || !(raw instanceof Array)) {
            return false;
        }
        var arr = raw as Array;
        if (arr.size() != 1) {
            return false;
        }
        var dict = arr[0] as Dictionary;
        var ref = dict.get("scripture_ref") as String;
        return ref == "jhn.3.16";
    }

    function testDeleteOutOfBounds(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeTestEntry("gen.1.1", "Genesis 1:1"));
        var result = BibleStorage.deleteEntry(5);
        return !result;
    }

    function testDeleteNegativeIndex(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeTestEntry("gen.1.1", "Genesis 1:1"));
        var result = BibleStorage.deleteEntry(-1);
        return !result;
    }

    // -----------------------------------------------------------------------
    // Count tests
    // -----------------------------------------------------------------------

    function testGetCountEmpty(logger as Test.Logger) as Boolean {
        clearStorage();
        return BibleStorage.getCount() == 0;
    }

    function testGetCountAfterSave(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeTestEntry("gen.1.1", "Genesis 1:1"));
        BibleStorage.saveEntry(makeTestEntry("jhn.3.16", "John 3:16"));
        return BibleStorage.getCount() == 2;
    }

    function testGetCountAfterDelete(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeTestEntry("gen.1.1", "Genesis 1:1"));
        BibleStorage.saveEntry(makeTestEntry("jhn.3.16", "John 3:16"));
        BibleStorage.deleteEntry(0);
        return BibleStorage.getCount() == 1;
    }

    // -----------------------------------------------------------------------
    // Persistence tests
    // -----------------------------------------------------------------------

    function testPersistenceAcrossReload(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeTestEntry("psa.23.1", "Psalms 23:1"));

        // Simulate app restart by reloading via Storage API directly
        var raw = Application.Storage.getValue(BibleStorage.COLLECTION_KEY);
        if (raw == null || !(raw instanceof Array)) {
            return false;
        }
        var arr = raw as Array;
        if (arr.size() != 1) {
            return false;
        }
        var dict = arr[0] as Dictionary;
        var ref = dict.get("scripture_ref") as String;
        return ref == "psa.23.1";
    }

    function testClearAll(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeTestEntry("gen.1.1", "Genesis 1:1"));
        BibleStorage.saveEntry(makeTestEntry("jhn.3.16", "John 3:16"));
        BibleStorage.clearAll();
        return BibleStorage.getCount() == 0;
    }

    // -----------------------------------------------------------------------
    // Save status enum tests (Fix 3)
    // -----------------------------------------------------------------------

    function testSaveStatusSavedValue(logger as Test.Logger) as Boolean {
        return BibleStorage.SAVE_STATUS_SAVED == 1;
    }

    function testSaveStatusDuplicateValue(logger as Test.Logger) as Boolean {
        return BibleStorage.SAVE_STATUS_DUPLICATE == 2;
    }

    function testSaveStatusFailedValue(logger as Test.Logger) as Boolean {
        return BibleStorage.SAVE_STATUS_FAILED == 3;
    }

    function testSaveReturnsSavedForNewEntry(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeTestEntry("gen.1.1", "Genesis 1:1");
        var status = BibleStorage.saveEntry(entry);
        return status == BibleStorage.SAVE_STATUS_SAVED && BibleStorage.getCount() == 1;
    }

    function testSaveReturnsDuplicateForExistingRef(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeTestEntry("jhn.3.16", "John 3:16");
        BibleStorage.saveEntry(entry);
        var status = BibleStorage.saveEntry(entry);
        return status == BibleStorage.SAVE_STATUS_DUPLICATE && BibleStorage.getCount() == 1;
    }

    function testSaveReturnsFailedForEmptyDict(logger as Test.Logger) as Boolean {
        clearStorage();
        var empty = {} as Dictionary;
        var status = BibleStorage.saveEntry(empty);
        return status == BibleStorage.SAVE_STATUS_FAILED && BibleStorage.getCount() == 0;
    }

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------

    function testSaveWithNullRefRejected(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeTestEntry("jhn.3.16", "John 3:16");
        entry.put("scripture_ref", null);
        // Null ref should be rejected, not saved
        var saved = BibleStorage.saveEntry(entry);
        return saved == BibleStorage.SAVE_STATUS_FAILED && BibleStorage.getCount() == 0;
    }

    function testSaveWithEmptyRefRejected(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeTestEntry("", "");
        entry.put("scripture_ref", "");
        // Empty ref should be rejected
        var saved = BibleStorage.saveEntry(entry);
        return saved == BibleStorage.SAVE_STATUS_FAILED && BibleStorage.getCount() == 0;
    }

    function testLoadAllIgnoresNonDictionaryItems(logger as Test.Logger) as Boolean {
        clearStorage();
        // Manually inject a bad array with a String element
        var badArray = [] as Array;
        badArray.add("not a dictionary");
        badArray.add(makeTestEntry("gen.1.1", "Genesis 1:1"));
        Application.Storage.setValue(BibleStorage.COLLECTION_KEY, badArray as Application.Storage.ValueType);

        var loaded = BibleStorage.loadAll();
        return loaded.size() == 1;
    }

    function testEntryOrderIsAppendOrder(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeTestEntry("gen.1.1", "Genesis 1:1"));
        BibleStorage.saveEntry(makeTestEntry("exo.1.1", "Exodus 1:1"));
        BibleStorage.saveEntry(makeTestEntry("lev.1.1", "Leviticus 1:1"));

        var loaded = BibleStorage.loadAll();
        if (loaded.size() != 3) {
            return false;
        }
        var ref0 = (loaded[0] as Dictionary).get("scripture_ref") as String;
        var ref1 = (loaded[1] as Dictionary).get("scripture_ref") as String;
        var ref2 = (loaded[2] as Dictionary).get("scripture_ref") as String;
        return ref0 == "gen.1.1" && ref1 == "exo.1.1" && ref2 == "lev.1.1";
    }
}
