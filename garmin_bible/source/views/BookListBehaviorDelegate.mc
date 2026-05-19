using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class BookListBehaviorDelegate extends Ui.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Up button: scroll selection up by one book
    function onPreviousPage() as Boolean {
        scrollUp();
        return true;
    }

    // Down button: scroll selection down by one book
    function onNextPage() as Boolean {
        scrollDown();
        return true;
    }

    // Enter/Select button: push ChapterListView for selected book
    function onSelect() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Set the passage state from the selected book
        state.bookIndex = state.selectedBookIndex;
        state.chapter = 1;
        state.startVerse = 1;
        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, 1);
        if (maxVerse <= 0) {
            maxVerse = 1;
        }
        state.endVerse = maxVerse;

        // Transition to ChapterListView
        var chapterView = new ChapterListView();
        var chapterDelegate = new ChapterListBehaviorDelegate(chapterView);
        Ui.pushView(chapterView, chapterDelegate, Ui.SLIDE_LEFT);
        return true;
    }

    // Back button: quit app, or reset filter if filtered
    function onBack() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        if (state.filterIndex != 0) {
            // Reset filter to "All"
            state.filterIndex = 0;
            var allBooks = BibleBooks.getFilteredBooks("All");
            if (allBooks.size() > 0) {
                state.selectedBookIndex = allBooks[0];
            }
            state.bookScroll = 0;
            Ui.requestUpdate();
            return true;
        }

        // Quit the app
        return false;
    }

    // Menu button: open BookFilterView
    function onMenu() as Boolean {
        var filterView = new BookFilterView();
        var filterDelegate = new BookFilterBehaviorDelegate();
        Ui.pushView(filterView, filterDelegate, Ui.SLIDE_UP);
        return true;
    }

    // Left button: go to Collection view
    function onPreviousMode() as Boolean {
        // For now, just consume the event. CollectionView is a future feature.
        // The feature description says "Left=go to Collection" — we'll wire it
        // when CollectionView is implemented. For now, return true to indicate
        // the event was consumed (prevents system default behavior).
        return true;
    }

    // Right button: also goes to Collection
    function onNextMode() as Boolean {
        return onPreviousMode();
    }

    // --- Private helpers ---

    private function scrollUp() as Void {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var filteredBooks = state.getFilteredBookIndices();
        var total = filteredBooks.size();

        if (total == 0) {
            return;
        }

        // Find current position in filtered list
        var currentPos = findBookInFilteredList(state.selectedBookIndex, filteredBooks);

        if (currentPos > 0) {
            currentPos = currentPos - 1;
        }
        // Clamp at first book (no wrap)

        state.selectedBookIndex = filteredBooks[currentPos];
        state.bookScroll = computeScrollForPosition(currentPos, state.bookScroll, total);
        Ui.requestUpdate();
    }

    private function scrollDown() as Void {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var filteredBooks = state.getFilteredBookIndices();
        var total = filteredBooks.size();

        if (total == 0) {
            return;
        }

        // Find current position in filtered list
        var currentPos = findBookInFilteredList(state.selectedBookIndex, filteredBooks);

        if (currentPos < total - 1) {
            currentPos = currentPos + 1;
        }
        // Clamp at last book (no wrap)

        state.selectedBookIndex = filteredBooks[currentPos];
        state.bookScroll = computeScrollForPosition(currentPos, state.bookScroll, total);
        Ui.requestUpdate();
    }

    // Find the position of a book index within the filtered list
    private function findBookInFilteredList(
        bookIndex as Number,
        filteredBooks as Array<Number>
    ) as Number {
        for (var i = 0; i < filteredBooks.size(); i++) {
            if (filteredBooks[i] == bookIndex) {
                return i;
            }
        }
        return 0;
    }

    // Compute the scroll offset so the selected item is visible
    private function computeScrollForPosition(
        pos as Number,
        currentScroll as Number,
        total as Number
    ) as Number {
        // Estimate visible rows (we don't have dc here, use a conservative estimate)
        // On a 176x176 screen with HEADER_HEIGHT=14 and LINE_HEIGHT=14:
        // contentHeight = 176 - 14 - 2 = 160; maxVisible = 160 / 14 = ~11
        var maxVisible = 11;

        var scroll = currentScroll;
        if (pos < scroll) {
            scroll = pos;
        } else if (pos >= scroll + maxVisible) {
            scroll = pos - maxVisible + 1;
        }

        // Clamp scroll to valid range
        if (scroll > total - maxVisible) {
            scroll = total - maxVisible;
        }
        if (scroll < 0) {
            scroll = 0;
        }

        return scroll;
    }
}
