import Toybox.Lang;
using Toybox.Test;
using Toybox.Application;

class CollectionViewTest {

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private function clearStorage() as Void {
        Application.Storage.setValue(BibleStorage.COLLECTION_KEY,
            [] as Application.Storage.ValueType);
    }

    private function makeEntry(
        ref as String,
        display as String,
        bookIdx as Number,
        chapter as Number,
        start as Number,
        end as Number,
        ts as String
    ) as Dictionary {
        var entry = {} as Dictionary;
        entry.put("scripture_ref", ref);
        entry.put("display_ref", display);
        entry.put("translation", "BSB");
        entry.put("book_index", bookIdx);
        entry.put("chapter", chapter);
        entry.put("start_verse", start);
        entry.put("end_verse", end);
        entry.put("captured_at", ts);
        return entry;
    }

    // -----------------------------------------------------------------------
    // Instantiation
    // -----------------------------------------------------------------------

    function testCollectionViewInstantiates(logger as Test.Logger) as Boolean {
        var view = new CollectionView();
        return view != null;
    }

    function testCollectionDelegateInstantiates(logger as Test.Logger) as Boolean {
        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        return delegate != null;
    }

    // -----------------------------------------------------------------------
    // Empty state
    // -----------------------------------------------------------------------

    function testEmptyCollectionShowsEmptyArray(logger as Test.Logger) as Boolean {
        clearStorage();
        var view = new CollectionView();
        return view.collection.size() == 0;
    }

    function testEmptyCollectionSelectedIndexZero(logger as Test.Logger) as Boolean {
        clearStorage();
        var view = new CollectionView();
        return view.selectedIndex == 0;
    }

    // -----------------------------------------------------------------------
    // List rendering — display_ref labels
    // -----------------------------------------------------------------------

    function testListShowsDisplayRef(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeEntry("jhn.3.16", "John 3:16", 42, 3, 16, 16, "2025-01-01T10:00:00Z");
        BibleStorage.saveEntry(entry);

        var view = new CollectionView();
        if (view.collection.size() != 1) {
            return false;
        }
        var first = view.collection[0] as Dictionary;
        return first.get("display_ref") == "John 3:16";
    }

    function testListShowsMultipleEntries(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));
        BibleStorage.saveEntry(makeEntry("jhn.3.16", "John 3:16", 42, 3, 16, 16, "2025-01-02T10:00:00Z"));

        var view = new CollectionView();
        return view.collection.size() == 2;
    }

    // -----------------------------------------------------------------------
    // Ordering — newest first (captured_at descending)
    // -----------------------------------------------------------------------

    function testNewestFirstOrder(logger as Test.Logger) as Boolean {
        clearStorage();
        var e1 = makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z");
        var e2 = makeEntry("jhn.3.16", "John 3:16", 42, 3, 16, 16, "2025-01-02T10:00:00Z");
        BibleStorage.saveEntry(e1);
        BibleStorage.saveEntry(e2);

        var view = new CollectionView();
        if (view.collection.size() != 2) {
            return false;
        }
        var first = view.collection[0] as Dictionary;
        var second = view.collection[1] as Dictionary;
        return first.get("display_ref") == "John 3:16" &&
               second.get("display_ref") == "Genesis 1:1";
    }

    function testNewestFirstWithThreeEntries(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));
        BibleStorage.saveEntry(makeEntry("exo.1.1", "Exodus 1:1", 1, 1, 1, 1, "2025-01-01T09:00:00Z"));
        BibleStorage.saveEntry(makeEntry("lev.1.1", "Leviticus 1:1", 2, 1, 1, 1, "2025-01-01T10:00:00Z"));

        var view = new CollectionView();
        if (view.collection.size() != 3) {
            return false;
        }
        var first = view.collection[0] as Dictionary;
        var last = view.collection[2] as Dictionary;
        return first.get("display_ref") == "Leviticus 1:1" &&
               last.get("display_ref") == "Genesis 1:1";
    }

    // -----------------------------------------------------------------------
    // Selection / scroll
    // -----------------------------------------------------------------------

    function testScrollDownIncrementsSelection(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));
        BibleStorage.saveEntry(makeEntry("jhn.3.16", "John 3:16", 42, 3, 16, 16, "2025-01-02T10:00:00Z"));

        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        view.selectedIndex = 0;
        delegate.onNextPage();
        return view.selectedIndex == 1;
    }

    function testScrollUpDecrementsSelection(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));
        BibleStorage.saveEntry(makeEntry("jhn.3.16", "John 3:16", 42, 3, 16, 16, "2025-01-02T10:00:00Z"));

        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        view.selectedIndex = 1;
        delegate.onPreviousPage();
        return view.selectedIndex == 0;
    }

    function testSelectionClampsAtTop(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));
        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        view.selectedIndex = 0;
        delegate.onPreviousPage();
        return view.selectedIndex == 0;
    }

    function testSelectionClampsAtBottom(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));
        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        view.selectedIndex = 0;
        delegate.onNextPage();
        return view.selectedIndex == 0;
    }

    // -----------------------------------------------------------------------
    // Load passage
    // -----------------------------------------------------------------------

    function testLoadPassageSetsState(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeEntry("jhn.3.16", "John 3:16", 42, 3, 16, 16, "2025-01-01T10:00:00Z");
        BibleStorage.saveEntry(entry);

        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);

        delegate.handleLoadPassage();

        var app = Application.getApp() as BibleApp;
        var state = app.state;
        return state.bookIndex == 42 &&
               state.chapter == 3 &&
               state.startVerse == 16 &&
               state.endVerse == 16 &&
               state.cameFromCollection;
    }

    function testLoadPassageSetsCameFromCollection(logger as Test.Logger) as Boolean {
        clearStorage();
        var entry = makeEntry("psa.23.1", "Psalms 23:1", 18, 23, 1, 1, "2025-01-01T10:00:00Z");
        BibleStorage.saveEntry(entry);

        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);

        delegate.handleLoadPassage();

        var app = Application.getApp() as BibleApp;
        var state = app.state;
        return state.cameFromCollection;
    }

    // -----------------------------------------------------------------------
    // Delete
    // -----------------------------------------------------------------------

    function testDeleteRemovesEntry(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));
        BibleStorage.saveEntry(makeEntry("jhn.3.16", "John 3:16", 42, 3, 16, 16, "2025-01-02T10:00:00Z"));

        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        view.selectedIndex = 0; // newest = John 3:16

        delegate.handleDelete();

        var all = BibleStorage.loadAll();
        if (all.size() != 1) {
            return false;
        }
        var remaining = all[0] as Dictionary;
        return remaining.get("scripture_ref") == "gen.1.1";
    }

    function testDeleteUpdatesViewCollection(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));
        BibleStorage.saveEntry(makeEntry("jhn.3.16", "John 3:16", 42, 3, 16, 16, "2025-01-02T10:00:00Z"));

        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        view.selectedIndex = 0;

        delegate.handleDelete();

        return view.collection.size() == 1;
    }

    function testDeleteShowsToast(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));
        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        view.selectedIndex = 0;

        delegate.handleDelete();

        return view.toastMessage != null &&
               (view.toastMessage as String).length() > 0 &&
               view.toastEndTime > System.getTimer();
    }

    function testDeleteOnEmptyDoesNothing(logger as Test.Logger) as Boolean {
        clearStorage();
        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        view.selectedIndex = 0;

        delegate.handleDelete();

        return BibleStorage.getCount() == 0;
    }

    // -----------------------------------------------------------------------
    // Navigation — Back / Left / Right return to BookList
    // -----------------------------------------------------------------------

    function testBackConsumesEvent(logger as Test.Logger) as Boolean {
        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        return delegate.onBack();
    }

    function testRightConsumesEvent(logger as Test.Logger) as Boolean {
        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        return delegate.onNextMode();
    }

    function testLeftConsumesEvent(logger as Test.Logger) as Boolean {
        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        return delegate.onPreviousMode();
    }

    // -----------------------------------------------------------------------
    // Refresh on show
    // -----------------------------------------------------------------------

    function testOnShowRefreshesCollection(logger as Test.Logger) as Boolean {
        clearStorage();
        var view = new CollectionView();
        if (view.collection.size() != 0) {
            return false;
        }
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));
        view.onShow();
        return view.collection.size() == 1;
    }

    // -----------------------------------------------------------------------
    // Delete middle entry preserves others
    // -----------------------------------------------------------------------

    function testDeleteMiddleEntryPreservesOthers(logger as Test.Logger) as Boolean {
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));
        BibleStorage.saveEntry(makeEntry("exo.1.1", "Exodus 1:1", 1, 1, 1, 1, "2025-01-01T09:00:00Z"));
        BibleStorage.saveEntry(makeEntry("lev.1.1", "Leviticus 1:1", 2, 1, 1, 1, "2025-01-01T10:00:00Z"));

        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        // View order: [Lev, Exo, Gen]; index 1 = Exodus
        view.selectedIndex = 1;

        delegate.handleDelete();

        var all = BibleStorage.loadAll();
        if (all.size() != 2) {
            return false;
        }
        var ref0 = (all[0] as Dictionary).get("scripture_ref") as String;
        var ref1 = (all[1] as Dictionary).get("scripture_ref") as String;
        return ref0 == "gen.1.1" && ref1 == "lev.1.1";
    }

    // -----------------------------------------------------------------------
    // Fix 2: Scroll indicator safe margins
    // -----------------------------------------------------------------------

    function testScrollIndicatorCollectionUsesMarginTop(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var marginTop = layout.get("marginTop") as Number;
        var trackTop = marginTop + BibleLayout.HEADER_HEIGHT;
        // Must not be below marginTop
        return trackTop >= marginTop + BibleLayout.HEADER_HEIGHT;
    }

    function testScrollIndicatorCollectionUsesMarginBottom(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var screenHeight = layout.get("screenHeight") as Number;
        var marginBottom = layout.get("marginBottom") as Number;
        var trackBottom = screenHeight - marginBottom;
        // Must not extend past safe margin
        return trackBottom <= screenHeight - marginBottom;
    }

    // -----------------------------------------------------------------------
    // Fix 4: Collection load resets filter when book not in current filter
    // -----------------------------------------------------------------------

    function testCollectionLoadSyncsFilterToAllWhenMismatch(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Set "R" filter (Ruth, Romans, Revelation only)
        state.filterIndex = 15;
        state.selectedBookIndex = 7;
        state.bookScroll = 0;

        // Create a CollectionBehaviorDelegate and simulate loading Genesis via handleLoadPassage
        // We need to set up a collection entry for Genesis
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gen.1.1", "Genesis 1:1", 0, 1, 1, 1, "2025-01-01T08:00:00Z"));

        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        view.selectedIndex = 0;

        delegate.handleLoadPassage();

        // After loading, filter should reset to "All" because Genesis is not in "R"
        return state.filterIndex == 0 && state.selectedBookIndex == 0;
    }

    function testCollectionLoadKeepsFilterWhenBookMatches(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Set "G" filter (Genesis, Galatians)
        state.filterIndex = 5;
        state.selectedBookIndex = 0;
        state.bookScroll = 0;

        // Create a CollectionBehaviorDelegate and simulate loading Galatians
        clearStorage();
        BibleStorage.saveEntry(makeEntry("gal.1.1", "Galatians 1:1", 47, 1, 1, 1, "2025-01-01T08:00:00Z"));

        var view = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(view);
        view.selectedIndex = 0;

        delegate.handleLoadPassage();

        // After loading, filter should stay "G" because Galatians matches
        return state.filterIndex == 5 && state.selectedBookIndex == 47;
    }
}
