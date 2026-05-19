using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.System;

class ActionMenuBehaviorDelegate extends Ui.BehaviorDelegate {
    var menuView as ActionMenuView;

    function initialize(menu as ActionMenuView) {
        BehaviorDelegate.initialize();
        menuView = menu;
    }

    // Up button: move selection up (Back -> Share -> Save)
    function onPreviousPage() as Boolean {
        if (menuView.selectedItem > 0) {
            menuView.selectedItem = menuView.selectedItem - 1;
        }
        Ui.requestUpdate();
        return true;
    }

    // Down button: move selection down (Save -> Share -> Back)
    function onNextPage() as Boolean {
        if (menuView.selectedItem < 2) {
            menuView.selectedItem = menuView.selectedItem + 1;
        }
        Ui.requestUpdate();
        return true;
    }

    // Enter (short): confirm selected menu item
    function onSelect() as Boolean {
        if (menuView.selectedItem == 0) {
            // Save
            savePassageAndShowToast();
            closeMenuAndReturn();
        } else if (menuView.selectedItem == 1) {
            // Share — push ShareView with route.bible URL
            closeMenuAndReturn();
            var app = Application.getApp() as BibleApp;
            var state = app.state;
            var shareUrl = BibleShare.buildUrl(state);
            var shareView = new ShareView(shareUrl);
            var shareDelegate = new ShareBehaviorDelegate(shareView);
            Ui.pushView(shareView, shareDelegate, Ui.SLIDE_UP);
        } else if (menuView.selectedItem == 2) {
            // Back — close menu, return to reader
            closeMenuAndReturn();
        }
        return true;
    }

    // Back button: close menu, return to reader
    function onBack() as Boolean {
        closeMenuAndReturn();
        return true;
    }

    private function closeMenuAndReturn() as Void {
        Ui.popView(Ui.SLIDE_DOWN);
    }

    private function savePassageAndShowToast() as Void {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Validate passage state before saving
        if (!BibleError.isValidPassageState(state)) {
            showToastMessage(state, BibleError.MSG_LOAD_FAILED);
            return;
        }

        // Build a collection entry via BibleStorage
        var entry = BibleStorage.buildEntry(state);

        // Check for collection full before saving
        if (BibleError.isCollectionFull()) {
            showToastMessage(state, BibleError.MSG_COLLECTION_FULL);
            return;
        }

        // Delegate to BibleStorage module
        var saved = BibleStorage.saveEntry(entry);
        if (saved) {
            showToastMessage(state, WatchUi.loadResource(Rez.Strings.Saved) as String);
        } else {
            showToastMessage(state, "Already saved");
        }
    }

    private function showToastMessage(state as BibleState, msg as String) as Void {
        BibleError.showToast(state, msg, 1500);
    }
}
