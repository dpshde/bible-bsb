using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.System;

class ReaderBehaviorDelegate extends Ui.BehaviorDelegate {
    var view as Ui.View;
    var selectPressTime as Number;
    var isLongPress as Boolean;

    // Long press threshold in milliseconds
    private const LONG_PRESS_MS = 500;

    function initialize(v as Ui.View) {
        BehaviorDelegate.initialize();
        view = v;
        selectPressTime = 0;
        isLongPress = false;
    }

    // Up button: scroll up by one line
    function onPreviousPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var maxS = BibleRenderer.maxScroll(state.readerLines.size(), state.readerLinesPerPage);
        state.readerScroll = BibleRenderer.scrollUp(state.readerScroll);
        state.readerScroll = BibleRenderer.clampScroll(state.readerScroll, maxS);
        Ui.requestUpdate();
        return true;
    }

    // Down button: scroll down by one line
    function onNextPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var maxS = BibleRenderer.maxScroll(state.readerLines.size(), state.readerLinesPerPage);
        state.readerScroll = BibleRenderer.scrollDown(state.readerScroll, maxS);
        Ui.requestUpdate();
        return true;
    }

    // Left button: page back (previous page)
    function onPreviousMode() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var maxS = BibleRenderer.maxScroll(state.readerLines.size(), state.readerLinesPerPage);
        state.readerScroll = BibleRenderer.pageLeft(state.readerScroll, state.readerLinesPerPage);
        state.readerScroll = BibleRenderer.clampScroll(state.readerScroll, maxS);
        Ui.requestUpdate();
        return true;
    }

    // Right button: page forward (next page)
    function onNextMode() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var maxS = BibleRenderer.maxScroll(state.readerLines.size(), state.readerLinesPerPage);
        state.readerScroll = BibleRenderer.pageRight(state.readerScroll, maxS, state.readerLinesPerPage);
        Ui.requestUpdate();
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
            // Long press: quick save
            isLongPress = true;
            handleQuickSave();
        } else {
            // Short press: open ActionMenu
            isLongPress = false;
            openActionMenu();
        }
        return true;
    }

    private function openActionMenu() as Void {
        var menuView = new ActionMenuView(view);
        var menuDelegate = new ActionMenuBehaviorDelegate(menuView);
        Ui.pushView(menuView, menuDelegate, Ui.SLIDE_UP);
    }

    private function handleQuickSave() as Void {
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
        Ui.requestUpdate();
    }

    // Back button: return to previous view (VerseSelect or Collection)
    function onBack() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Clear reader lines on back to free memory
        state.readerLines = [] as Array<Dictionary>;
        state.readerScroll = 0;
        state.readerToastMessage = "";
        state.readerToastEndTime = 0;

        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }
}
