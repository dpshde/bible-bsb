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
            // Share — push ShareView (placeholder until ShareView implemented)
            // For now, pop menu and return to reader
            closeMenuAndReturn();
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

        // Build a collection entry via BibleStorage
        var entry = BibleStorage.buildEntry(state);

        // Delegate to BibleStorage module
        BibleStorage.saveEntry(entry);

        showSavedToast(state);
    }

    private function showSavedToast(state as BibleState) as Void {
        state.readerToastMessage = WatchUi.loadResource(Rez.Strings.Saved) as String;
        state.readerToastEndTime = System.getTimer() + 1500;
    }
}
