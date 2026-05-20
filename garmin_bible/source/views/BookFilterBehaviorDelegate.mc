using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class BookFilterBehaviorDelegate extends Ui.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Up button: move backward one filter in the same incremental snake order
    // used by the filter grid.
    function onPreviousPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        if (state.filterIndex > 0) {
            state.filterIndex = state.filterIndex - 1;
        }

        Ui.requestUpdate();
        return true;
    }

    // Down button: move forward one filter in the same incremental snake order
    // used by the filter grid.
    function onNextPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var total = BibleBooks.FILTER_COUNT;

        if (state.filterIndex + 1 < total) {
            state.filterIndex = state.filterIndex + 1;
        }

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

    // Tap handler for touch devices: treat as select/confirm
    function onTap(tapEvent as Ui.ClickEvent) as Boolean {
        if (!BibleLayout.hasTouchScreen()) {
            return false;
        }
        return onSelect();
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
