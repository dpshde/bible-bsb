using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.System;

class CollectionBehaviorDelegate extends Ui.BehaviorDelegate {
    var view as CollectionView;
    var selectPressTime as Number;
    var isLongPress as Boolean;

    // Long press threshold in milliseconds
    private const LONG_PRESS_MS = 500;

    function initialize(v as CollectionView) {
        BehaviorDelegate.initialize();
        view = v;
        selectPressTime = 0;
        isLongPress = false;
    }

    // Up button: scroll selection up
    function onPreviousPage() as Boolean {
        if (view.selectedIndex > 0) {
            view.selectedIndex = view.selectedIndex - 1;
        }
        Ui.requestUpdate();
        return true;
    }

    // Down button: scroll selection down
    function onNextPage() as Boolean {
        if (view.selectedIndex < view.collection.size() - 1) {
            view.selectedIndex = view.selectedIndex + 1;
        }
        Ui.requestUpdate();
        return true;
    }

    // Left button: return to BookList
    function onPreviousMode() as Boolean {
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }

    // Right button: return to BookList
    function onNextMode() as Boolean {
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }

    // Enter pressed: start tracking for long press detection
    function onSelect() as Boolean {
        selectPressTime = System.getTimer();
        isLongPress = false;
        return true;
    }

    // Enter released: decide short vs long press
    function onSelectUp() as Boolean {
        var elapsed = System.getTimer() - selectPressTime;
        if (elapsed >= LONG_PRESS_MS) {
            isLongPress = true;
            handleDelete();
        } else {
            isLongPress = false;
            handleLoadPassage();
        }
        return true;
    }

    // Load the selected passage into ReaderView
    function handleLoadPassage() as Void {
        if (view.collection == null || view.collection.size() == 0) {
            return;
        }
        if (view.selectedIndex < 0 || view.selectedIndex >= view.collection.size()) {
            return;
        }

        var entry = view.collection[view.selectedIndex] as Dictionary;
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Load passage state from entry
        state.bookIndex = entry.get("book_index") as Number;
        state.chapter = entry.get("chapter") as Number;
        state.startVerse = entry.get("start_verse") as Number;
        state.endVerse = entry.get("end_verse") as Number;
        state.cameFromCollection = true;

        // Push ReaderView
        var readerView = new ReaderView();
        var readerDelegate = new ReaderBehaviorDelegate(readerView);
        Ui.pushView(readerView, readerDelegate, Ui.SLIDE_LEFT);
    }

    // Delete the selected passage and show a toast
    function handleDelete() as Void {
        if (view.collection == null || view.collection.size() == 0) {
            return;
        }
        if (view.selectedIndex < 0 || view.selectedIndex >= view.collection.size()) {
            return;
        }

        // The view collection is reversed (newest first).
        // Storage keeps oldest at index 0, so storage index = storage.size() - 1 - view.selectedIndex
        var all = BibleStorage.loadAll();
        var storageIndex = all.size() - 1 - view.selectedIndex;

        var deleted = BibleStorage.deleteEntry(storageIndex);
        if (deleted) {
            view.refreshCollection();
            if (view.selectedIndex >= view.collection.size() && view.collection.size() > 0) {
                view.selectedIndex = view.collection.size() - 1;
            }
            Ui.requestUpdate();

            // Show toast on the collection view
            view.toastMessage = WatchUi.loadResource(Rez.Strings.Deleted) as String;
            view.toastEndTime = System.getTimer() + 1500;
        }
    }

    // Tap handler for touch devices: load passage (short tap equivalent)
    function onTap(tapEvent as Ui.ClickEvent) as Boolean {
        if (!BibleLayout.hasTouchScreen()) {
            return false;
        }
        handleLoadPassage();
        return true;
    }

    // Swipe handler for touch devices: scroll collection
    function onSwipe(swipeEvent as Ui.SwipeEvent) as Boolean {
        if (!BibleLayout.hasTouchScreen()) {
            return false;
        }
        var direction = swipeEvent.getDirection();
        if (direction == Ui.SWIPE_UP) {
            return onNextPage();
        } else if (direction == Ui.SWIPE_DOWN) {
            return onPreviousPage();
        }
        return false;
    }

    // Back button: return to BookList
    function onBack() as Boolean {
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }
}
