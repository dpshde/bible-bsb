using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class BookFilterBehaviorDelegate extends Ui.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Up button: move selection up by one row
    function onPreviousPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var total = BibleBooks.FILTER_COUNT;
        var cols = 5;

        if (state.filterIndex >= cols) {
            state.filterIndex = state.filterIndex - cols;
        }
        // Clamp at top row (no wrap)

        Ui.requestUpdate();
        return true;
    }

    // Down button: move selection down by one row
    function onNextPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var total = BibleBooks.FILTER_COUNT;
        var cols = 5;

        if (state.filterIndex + cols < total) {
            state.filterIndex = state.filterIndex + cols;
        } else if (state.filterIndex < total - 1) {
            // Snap to last option if moving down from row above last partial row
            state.filterIndex = total - 1;
        }
        // Clamp at last option (no wrap)

        Ui.requestUpdate();
        return true;
    }

    // Left button: move selection left by one column, or go back if at "All"
    function onPreviousMode() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        if (state.filterIndex == 0) {
            // On "All", left arrow goes back to book list without applying
            applyFilterAndPop();
            return true;
        }

        if (state.filterIndex > 0) {
            state.filterIndex = state.filterIndex - 1;
        }

        Ui.requestUpdate();
        return true;
    }

    // Right button: move selection right by one column
    function onNextMode() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var total = BibleBooks.FILTER_COUNT;

        if (state.filterIndex + 1 < total) {
            state.filterIndex = state.filterIndex + 1;
        }

        Ui.requestUpdate();
        return true;
    }

    // Enter/Select button: apply filter and return to BookList
    function onSelect() as Boolean {
        applyFilterAndPop();
        return true;
    }

    // Back button: apply filter and return to BookList
    function onBack() as Boolean {
        applyFilterAndPop();
        return true;
    }

    // Apply the selected filter, update BookList state, and pop back
    private function applyFilterAndPop() as Void {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        var filterOpt = BibleBooks.getFilterOption(state.filterIndex);
        var filteredBooks = BibleBooks.getFilteredBooks(filterOpt);

        if (filteredBooks.size() > 0) {
            state.selectedBookIndex = filteredBooks[0];
        }
        state.bookScroll = 0;

        // Pop back to BookList
        Ui.popView(Ui.SLIDE_DOWN);
    }
}
