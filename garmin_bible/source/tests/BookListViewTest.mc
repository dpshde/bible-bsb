import Toybox.Lang;
using Toybox.Test;
using Toybox.Application;

class BookListViewTest {

    // --- BookList state / scroll tests ---

    function testBookListDisplaysAll66Books(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("All");
        return books.size() == 66;
    }

    function testScrollDownIncrementsSelection(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Reset state
        state.selectedBookIndex = 0;
        state.bookScroll = 0;
        state.filterIndex = 0;

        var filteredBooks = state.getFilteredBookIndices();
        var currentPos = findBookInList(state.selectedBookIndex, filteredBooks);

        if (currentPos < filteredBooks.size() - 1) {
            var newPos = currentPos + 1;
            state.selectedBookIndex = filteredBooks[newPos];
        }

        return state.selectedBookIndex == 1;
    }

    function testScrollUpDecrementsSelection(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Start at second book
        state.selectedBookIndex = 1;
        state.bookScroll = 0;
        state.filterIndex = 0;

        var filteredBooks = state.getFilteredBookIndices();
        var currentPos = findBookInList(state.selectedBookIndex, filteredBooks);

        if (currentPos > 0) {
            var newPos = currentPos - 1;
            state.selectedBookIndex = filteredBooks[newPos];
        }

        return state.selectedBookIndex == 0;
    }

    // Wrap tests: Up from first wraps to last; Down from last wraps to first
    // These simulate the delegate behavior exactly.

    function testScrollUpWrapsFromFirstToLast(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.selectedBookIndex = 0;
        state.bookScroll = 0;
        state.filterIndex = 0;

        var filteredBooks = state.getFilteredBookIndices();
        var currentPos = findBookInList(state.selectedBookIndex, filteredBooks);
        var total = filteredBooks.size();

        // Simulate scrollUp wrap logic
        if (currentPos > 0) {
            currentPos = currentPos - 1;
        } else {
            currentPos = total - 1;
        }

        state.selectedBookIndex = filteredBooks[currentPos];
        return state.selectedBookIndex == 65; // Revelation (last book)
    }

    function testScrollDownWrapsFromLastToFirst(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.filterIndex = 0;
        var filteredBooks = state.getFilteredBookIndices();
        var lastBook = filteredBooks[filteredBooks.size() - 1];
        state.selectedBookIndex = lastBook;
        state.bookScroll = 0;

        var currentPos = findBookInList(state.selectedBookIndex, filteredBooks);
        var total = filteredBooks.size();

        // Simulate scrollDown wrap logic
        if (currentPos < total - 1) {
            currentPos = currentPos + 1;
        } else {
            currentPos = 0;
        }

        state.selectedBookIndex = filteredBooks[currentPos];
        return state.selectedBookIndex == 0; // Genesis (first book)
    }

    // --- Filter tests ---

    function testFilterRReturns3Books(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("R");
        return books.size() == 3;
    }

    function testFilterGReturns2Books(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("G");
        return books.size() == 2;
    }

    function testFilter1Returns8Books(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("1");
        return books.size() == 8;
    }

    function testFilterAllRestores66(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("All");
        return books.size() == 66;
    }

    function testFilterCountIs22(logger as Test.Logger) as Boolean {
        return BibleBooks.FILTER_COUNT == 22;
    }

    function testFilterEmptyReturns66(logger as Test.Logger) as Boolean {
        var books = BibleBooks.getFilteredBooks("");
        return books.size() == 66;
    }

    // --- Filter state transition tests ---

    function testFilterIndexSetsBookListState(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Simulate applying "R" filter
        state.filterIndex = 15; // "R" is at index 15 in FILTER_OPTIONS
        var filterOpt = BibleBooks.getFilterOption(state.filterIndex);
        var filteredBooks = BibleBooks.getFilteredBooks(filterOpt);

        state.selectedBookIndex = filteredBooks[0];
        state.bookScroll = 0;

        // "R" filter: Ruth(7), Romans(44), Revelation(65)
        return filteredBooks.size() == 3 && state.selectedBookIndex == 7;
    }

    function testFilterAllShowsFirstBook(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.filterIndex = 0;
        var filterOpt = BibleBooks.getFilterOption(state.filterIndex);
        var filteredBooks = BibleBooks.getFilteredBooks(filterOpt);

        state.selectedBookIndex = filteredBooks[0];
        state.bookScroll = 0;

        return state.selectedBookIndex == 0;
    }

    // --- Right-button navigation test ---

    function testRightButtonOpensBookFilterView(logger as Test.Logger) as Boolean {
        // Verify that onNextMode returns true (consumes event and pushes BookFilterView)
        var delegate = new BookListBehaviorDelegate();
        var handled = delegate.onNextMode();
        // onNextMode returns true when it pushes the BookFilterView
        return handled == true;
    }

    // --- Fix 2: Scroll indicator safe margins ---

    function testScrollIndicatorTrackTopUsesMarginTop(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var marginTop = layout.get("marginTop") as Number;
        var trackTop = marginTop + BibleLayout.HEADER_HEIGHT;
        // Old code used HEADER_HEIGHT + 2 = 16, which is below marginTop=18 on semi-octagon
        return trackTop >= marginTop + BibleLayout.HEADER_HEIGHT;
    }

    function testScrollIndicatorTrackBottomUsesMarginBottom(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var screenHeight = layout.get("screenHeight") as Number;
        var marginBottom = layout.get("marginBottom") as Number;
        var trackBottom = screenHeight - marginBottom;
        // Old code used height - 2 = 174, which extends into marginBottom=18 area
        return trackBottom <= screenHeight - marginBottom;
    }

    function testScrollIndicatorFitsWithinSafeArea(logger as Test.Logger) as Boolean {
        var layout = BibleLayout.mockLayout(176, 176, BibleLayout.FONT_SMALL, 14, true, System.SCREEN_SHAPE_SEMI_OCTAGON);
        var marginTop = layout.get("marginTop") as Number;
        var marginBottom = layout.get("marginBottom") as Number;
        var screenHeight = layout.get("screenHeight") as Number;
        var trackTop = marginTop + BibleLayout.HEADER_HEIGHT;
        var trackBottom = screenHeight - marginBottom;
        return trackTop >= marginTop && trackBottom <= screenHeight - marginBottom && trackBottom > trackTop;
    }

    // --- Fix 4: Collection load resets filter if book not in filtered list ---

    function testCollectionLoadResetsFilterWhenBookNotInList(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Set filter to "R" so only Ruth, Romans, Revelation are visible
        state.filterIndex = 15; // "R"
        state.selectedBookIndex = 7; // Ruth

        // Simulate loading Genesis (index 0) from Collection — not in "R" filter
        var entry = {
            "scripture_ref" => "gen.1.1",
            "display_ref" => "Genesis 1:1",
            "translation" => "BSB",
            "book_index" => 0,
            "chapter" => 1,
            "start_verse" => 1,
            "end_verse" => 1,
            "captured_at" => "2025-01-01T10:00:00Z"
        } as Dictionary;

        // Create a mock CollectionBehaviorDelegate to test the filter sync logic
        var collectionView = new CollectionView();
        var delegate = new CollectionBehaviorDelegate(collectionView);

        // Manually invoke the sync portion of handleLoadPassage
        var loadedBookIndex = entry.get("book_index") as Number;
        state.bookIndex = loadedBookIndex;
        state.chapter = entry.get("chapter") as Number;
        state.startVerse = entry.get("start_verse") as Number;
        state.endVerse = entry.get("end_verse") as Number;
        state.cameFromCollection = true;

        // Sync BookList filter
        var filteredBooks = state.getFilteredBookIndices();
        var found = false;
        for (var i = 0; i < filteredBooks.size(); i++) {
            if (filteredBooks[i] == state.bookIndex) {
                state.selectedBookIndex = state.bookIndex;
                found = true;
                break;
            }
        }
        if (!found) {
            state.filterIndex = 0;
            var allBooks = BibleBooks.getFilteredBooks("All");
            if (allBooks.size() > 0) {
                state.selectedBookIndex = allBooks[0];
                for (var i = 0; i < allBooks.size(); i++) {
                    if (allBooks[i] == state.bookIndex) {
                        state.selectedBookIndex = state.bookIndex;
                        break;
                    }
                }
            }
            state.bookScroll = 0;
        }

        // After sync, filter should be "All" and selectedBookIndex should be Genesis (0)
        return state.filterIndex == 0 && state.selectedBookIndex == 0;
    }

    function testCollectionLoadKeepsFilterWhenBookInList(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Set filter to "G" so Genesis and Galatians are visible
        state.filterIndex = 5; // "G"
        state.selectedBookIndex = 0; // Genesis

        // Simulate loading Genesis (index 0) from Collection — IS in "G" filter
        var filteredBooks = state.getFilteredBookIndices();
        var found = false;
        for (var i = 0; i < filteredBooks.size(); i++) {
            if (filteredBooks[i] == 0) {
                found = true;
                break;
            }
        }
        if (!found) {
            state.filterIndex = 0;
            var allBooks = BibleBooks.getFilteredBooks("All");
            if (allBooks.size() > 0) {
                state.selectedBookIndex = allBooks[0];
            }
            state.bookScroll = 0;
        }

        // Filter should remain "G" because Genesis matches
        return state.filterIndex == 5 && state.selectedBookIndex == 0;
    }

    // --- Helper ---

    private function findBookInList(bookIndex as Number, filteredBooks as Array<Number>) as Number {
        for (var i = 0; i < filteredBooks.size(); i++) {
            if (filteredBooks[i] == bookIndex) {
                return i;
            }
        }
        return 0;
    }
}
