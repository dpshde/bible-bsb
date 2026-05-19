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

    function testSelectionClampsAtFirstBook(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.selectedBookIndex = 0;
        state.bookScroll = 0;
        state.filterIndex = 0;

        var filteredBooks = state.getFilteredBookIndices();
        var currentPos = findBookInList(state.selectedBookIndex, filteredBooks);

        // Try to scroll up past first
        if (currentPos > 0) {
            currentPos = currentPos - 1;
        }
        // Clamp at 0 — no wrap

        state.selectedBookIndex = filteredBooks[currentPos];
        return state.selectedBookIndex == 0;
    }

    function testSelectionClampsAtLastBook(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        state.filterIndex = 0;
        var filteredBooks = state.getFilteredBookIndices();
        var lastBook = filteredBooks[filteredBooks.size() - 1];
        state.selectedBookIndex = lastBook;
        state.bookScroll = 0;

        var currentPos = findBookInList(state.selectedBookIndex, filteredBooks);

        // Try to scroll down past last
        if (currentPos < filteredBooks.size() - 1) {
            currentPos = currentPos + 1;
        }
        // Clamp at last — no wrap

        state.selectedBookIndex = filteredBooks[currentPos];
        return state.selectedBookIndex == lastBook;
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

    function testFilterCountIs21(logger as Test.Logger) as Boolean {
        return BibleBooks.FILTER_COUNT == 21;
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
        state.filterIndex = 14; // "R" is at index 14 in FILTER_OPTIONS
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
