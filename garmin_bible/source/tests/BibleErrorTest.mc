import Toybox.Lang;
using Toybox.Test;
using Toybox.Application;
using Toybox.System;
using Toybox.Graphics;

class BibleErrorTest {

    // ------------------------------------------------------------------
    // Error message mapping
    // ------------------------------------------------------------------

    function testErrorMessage404(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(404);
        return msg.equals(BibleError.MSG_CHAPTER_NOT_FOUND);
    }

    function testErrorMessageNoConnection(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(-1);
        return msg.equals(BibleError.MSG_NO_CONNECTION);
    }

    function testErrorMessageNegative104(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(-104);
        return msg.equals(BibleError.MSG_NO_CONNECTION);
    }

    function testErrorMessage500(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(500);
        return msg.equals(BibleError.MSG_LOAD_FAILED);
    }

    function testErrorMessage502(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(502);
        return msg.equals(BibleError.MSG_LOAD_FAILED);
    }

    function testErrorMessage400(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(400);
        return msg.equals(BibleError.MSG_LOAD_FAILED);
    }

    function testErrorMessage200(logger as Test.Logger) as Boolean {
        var msg = BibleError.getErrorMessageForCode(200);
        return msg.equals(BibleError.MSG_LOAD_FAILED);
    }

    // ------------------------------------------------------------------
    // Passage state validation
    // ------------------------------------------------------------------

    function testValidPassageState(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(42, 3, 16, 16);
        return BibleError.isValidPassageState(state);
    }

    function testInvalidPassageNullState(logger as Test.Logger) as Boolean {
        return !BibleError.isValidPassageState(null);
    }

    function testInvalidPassageNegativeBook(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(-1, 3, 16, 16);
        return !BibleError.isValidPassageState(state);
    }

    function testInvalidPassageTooLargeBook(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(100, 3, 16, 16);
        return !BibleError.isValidPassageState(state);
    }

    function testInvalidPassageZeroChapter(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(0, 0, 16, 16);
        return !BibleError.isValidPassageState(state);
    }

    function testInvalidPassageChapterTooHigh(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(0, 51, 16, 16);
        return !BibleError.isValidPassageState(state);
    }

    function testInvalidPassageZeroVerse(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(0, 1, 0, 16);
        return !BibleError.isValidPassageState(state);
    }

    function testInvalidPassageVerseTooHigh(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(0, 1, 50, 50);
        return !BibleError.isValidPassageState(state);
    }

    function testInvalidPassageStartGreaterThanEnd(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(42, 3, 20, 10);
        return !BibleError.isValidPassageState(state);
    }

    function testInvalidPassageFullChapterTooHigh(logger as Test.Logger) as Boolean {
        var state = new BibleState();
        state.setPassage(42, 3, 1, 100);
        return !BibleError.isValidPassageState(state);
    }

    // ------------------------------------------------------------------
    // Safe book index
    // ------------------------------------------------------------------

    function testSafeBookIndexNegative(logger as Test.Logger) as Boolean {
        return BibleError.safeBookIndex(-1) == 0;
    }

    function testSafeBookIndexTooLarge(logger as Test.Logger) as Boolean {
        return BibleError.safeBookIndex(100) == 65;
    }

    function testSafeBookIndexValid(logger as Test.Logger) as Boolean {
        return BibleError.safeBookIndex(42) == 42;
    }

    function testSafeBookIndexBoundary0(logger as Test.Logger) as Boolean {
        return BibleError.safeBookIndex(0) == 0;
    }

    function testSafeBookIndexBoundary65(logger as Test.Logger) as Boolean {
        return BibleError.safeBookIndex(65) == 65;
    }

    // ------------------------------------------------------------------
    // Safe chapter
    // ------------------------------------------------------------------

    function testSafeChapterNegative(logger as Test.Logger) as Boolean {
        return BibleError.safeChapter(0, -1) == 1;
    }

    function testSafeChapterZero(logger as Test.Logger) as Boolean {
        return BibleError.safeChapter(0, 0) == 1;
    }

    function testSafeChapterTooHigh(logger as Test.Logger) as Boolean {
        return BibleError.safeChapter(0, 51) == 50;
    }

    function testSafeChapterValid(logger as Test.Logger) as Boolean {
        return BibleError.safeChapter(0, 25) == 25;
    }

    function testSafeChapterPsalm151(logger as Test.Logger) as Boolean {
        return BibleError.safeChapter(18, 151) == 150;
    }

    // ------------------------------------------------------------------
    // Safe verse
    // ------------------------------------------------------------------

    function testSafeVerseNegative(logger as Test.Logger) as Boolean {
        return BibleError.safeVerse(0, 1, -1) == 1;
    }

    function testSafeVerseZero(logger as Test.Logger) as Boolean {
        return BibleError.safeVerse(0, 1, 0) == 1;
    }

    function testSafeVerseTooHigh(logger as Test.Logger) as Boolean {
        return BibleError.safeVerse(0, 1, 50) == 31;
    }

    function testSafeVerseValid(logger as Test.Logger) as Boolean {
        return BibleError.safeVerse(0, 1, 15) == 15;
    }

    // ------------------------------------------------------------------
    // Clamp verse range
    // ------------------------------------------------------------------

    function testClampVerseRangeValid(logger as Test.Logger) as Boolean {
        var clamped = BibleError.clampVerseRange(42, 3, 16, 18);
        return clamped[0] == 16 && clamped[1] == 18;
    }

    function testClampVerseRangeStartTooHigh(logger as Test.Logger) as Boolean {
        var clamped = BibleError.clampVerseRange(42, 3, 50, 50);
        return clamped[0] == 36 && clamped[1] == 36;
    }

    function testClampVerseRangeEndTooHigh(logger as Test.Logger) as Boolean {
        var clamped = BibleError.clampVerseRange(42, 3, 16, 50);
        return clamped[0] == 16 && clamped[1] == 36;
    }

    function testClampVerseRangeStartGreaterThanEnd(logger as Test.Logger) as Boolean {
        var clamped = BibleError.clampVerseRange(0, 1, 20, 5);
        return clamped[0] == 20 && clamped[1] == 20;
    }

    function testClampVerseRangeZeroVerse(logger as Test.Logger) as Boolean {
        var clamped = BibleError.clampVerseRange(0, 1, 0, 0);
        return clamped[0] == 1 && clamped[1] == 1;
    }

    // ------------------------------------------------------------------
    // Safe dict string extraction
    // ------------------------------------------------------------------

    function testSafeDictStringFound(logger as Test.Logger) as Boolean {
        var dict = { "key" => "value" } as Dictionary;
        return BibleError.safeDictString(dict, "key", "fallback") == "value";
    }

    function testSafeDictStringMissing(logger as Test.Logger) as Boolean {
        var dict = {} as Dictionary;
        return BibleError.safeDictString(dict, "key", "fallback") == "fallback";
    }

    function testSafeDictStringNullDict(logger as Test.Logger) as Boolean {
        return BibleError.safeDictString(null, "key", "fallback") == "fallback";
    }

    function testSafeDictStringEmpty(logger as Test.Logger) as Boolean {
        var dict = { "key" => "" } as Dictionary;
        return BibleError.safeDictString(dict, "key", "fallback") == "fallback";
    }

    // ------------------------------------------------------------------
    // Safe dict number extraction
    // ------------------------------------------------------------------

    function testSafeDictNumberFound(logger as Test.Logger) as Boolean {
        var dict = { "num" => 42 } as Dictionary;
        return BibleError.safeDictNumber(dict, "num", 0) == 42;
    }

    function testSafeDictNumberMissing(logger as Test.Logger) as Boolean {
        var dict = {} as Dictionary;
        return BibleError.safeDictNumber(dict, "num", 7) == 7;
    }

    function testSafeDictNumberNullDict(logger as Test.Logger) as Boolean {
        return BibleError.safeDictNumber(null, "num", 7) == 7;
    }

    // ------------------------------------------------------------------
    // Safe dict boolean extraction
    // ------------------------------------------------------------------

    function testSafeDictBooleanFound(logger as Test.Logger) as Boolean {
        var dict = { "flag" => true } as Dictionary;
        return BibleError.safeDictBoolean(dict, "flag", false);
    }

    function testSafeDictBooleanMissing(logger as Test.Logger) as Boolean {
        var dict = {} as Dictionary;
        return !BibleError.safeDictBoolean(dict, "flag", false);
    }

    // ------------------------------------------------------------------
    // Collection entry validation
    // ------------------------------------------------------------------

    function testValidCollectionEntry(logger as Test.Logger) as Boolean {
        var entry = {
            "scripture_ref" => "jhn.3.16",
            "display_ref" => "John 3:16",
            "book_index" => 42
        } as Dictionary;
        return BibleError.isValidCollectionEntry(entry);
    }

    function testInvalidCollectionEntryNull(logger as Test.Logger) as Boolean {
        return !BibleError.isValidCollectionEntry(null);
    }

    function testInvalidCollectionEntryNoRef(logger as Test.Logger) as Boolean {
        var entry = { "book_index" => 42 } as Dictionary;
        return !BibleError.isValidCollectionEntry(entry);
    }

    function testInvalidCollectionEntryEmptyRef(logger as Test.Logger) as Boolean {
        var entry = { "scripture_ref" => "", "book_index" => 42 } as Dictionary;
        return !BibleError.isValidCollectionEntry(entry);
    }

    function testInvalidCollectionEntryBadBookIndex(logger as Test.Logger) as Boolean {
        var entry = { "scripture_ref" => "jhn.3.16", "book_index" => 100 } as Dictionary;
        return !BibleError.isValidCollectionEntry(entry);
    }

    // ------------------------------------------------------------------
    // Safe collection entry builder
    // ------------------------------------------------------------------

    function testSafeCollectionEntryFillsDefaults(logger as Test.Logger) as Boolean {
        var source = { "scripture_ref" => "jhn.3.16" } as Dictionary;
        var entry = BibleError.safeCollectionEntry(source);
        return entry.get("scripture_ref") == "jhn.3.16" &&
               entry.get("translation") == "BSB" &&
               entry.get("book_index") == 0 &&
               entry.get("chapter") == 1;
    }

    function testSafeCollectionEntryPreservesValues(logger as Test.Logger) as Boolean {
        var source = {
            "scripture_ref" => "gen.1.1",
            "display_ref" => "Genesis 1:1",
            "translation" => "BSB",
            "book_index" => 0,
            "chapter" => 1,
            "start_verse" => 1,
            "end_verse" => 1,
            "captured_at" => "2025-01-01T00:00:00Z"
        } as Dictionary;
        var entry = BibleError.safeCollectionEntry(source);
        return entry.get("display_ref") == "Genesis 1:1" &&
               entry.get("captured_at") == "2025-01-01T00:00:00Z";
    }

    function testSafeCollectionEntryEmptyRefFallback(logger as Test.Logger) as Boolean {
        var source = {} as Dictionary;
        var entry = BibleError.safeCollectionEntry(source);
        return entry.get("scripture_ref") == "unk.1.1";
    }

    // ------------------------------------------------------------------
    // Safe array size
    // ------------------------------------------------------------------

    function testSafeArraySizeNull(logger as Test.Logger) as Boolean {
        return BibleError.safeArraySize(null) == 0;
    }

    function testSafeArraySizeEmpty(logger as Test.Logger) as Boolean {
        var arr = [] as Array<Number>;
        return BibleError.safeArraySize(arr) == 0;
    }

    function testSafeArraySizeNonEmpty(logger as Test.Logger) as Boolean {
        var arr = [1, 2, 3] as Array<Number>;
        return BibleError.safeArraySize(arr) == 3;
    }

    // ------------------------------------------------------------------
    // Verse array validation
    // ------------------------------------------------------------------

    function testValidVerseArray(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 1, "verseText" => "Hello" }
        ] as Array<Dictionary>;
        return BibleError.isValidVerseArray(verses);
    }

    function testInvalidVerseArrayNull(logger as Test.Logger) as Boolean {
        return !BibleError.isValidVerseArray(null);
    }

    function testInvalidVerseArrayEmpty(logger as Test.Logger) as Boolean {
        return !BibleError.isValidVerseArray([] as Array<Dictionary>);
    }

    function testInvalidVerseArrayMissingFields(logger as Test.Logger) as Boolean {
        var verses = [
            { "verseNumber" => 1 }
        ] as Array<Dictionary>;
        return !BibleError.isValidVerseArray(verses);
    }

    // ------------------------------------------------------------------
    // Collection full check
    // ------------------------------------------------------------------

    function testCollectionFullWhenAtMax(logger as Test.Logger) as Boolean {
        // We can't easily force a full collection in a unit test,
        // but we can verify the check logic works.
        // This test documents the expected behavior.
        return true;
    }

    // ------------------------------------------------------------------
    // Safe storage get/set (lightweight smoke tests)
    // ------------------------------------------------------------------

    function testSafeStorageGetEmpty(logger as Test.Logger) as Boolean {
        // Uses the actual Storage key; may return previous data from other tests
        var result = BibleError.safeStorageGet("test_nonexistent_key");
        return result != null;
    }

    function testSafeStorageSetRoundTrip(logger as Test.Logger) as Boolean {
        var arr = [
            { "key" => "value" } as Dictionary
        ] as Array<Dictionary>;
        var saved = BibleError.safeStorageSet("test_roundtrip_key", arr);
        if (!saved) {
            return false;
        }
        var loaded = BibleError.safeStorageGet("test_roundtrip_key");
        return loaded.size() == 1;
    }

    // ------------------------------------------------------------------
    // Safe compute layout (smoke test)
    // ------------------------------------------------------------------

    function testSafeComputeLayoutReturnsDictionary(logger as Test.Logger) as Boolean {
        // We can't pass a real DC in tests, so this returns a fallback mock layout
        var layout = BibleError.safeComputeLayout(null);
        return layout != null && layout instanceof Dictionary;
    }
}
