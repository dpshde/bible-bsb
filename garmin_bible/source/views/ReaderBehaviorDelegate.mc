using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.System;

class ReaderBehaviorDelegate extends Ui.BehaviorDelegate {
    var view as Ui.View;

    function initialize(v as Ui.View) {
        BehaviorDelegate.initialize();
        view = v;
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

    // Enter: open ActionMenu (placeholder — future feature)
    function onSelect() as Boolean {
        // ActionMenu is a future feature. Consume the event.
        return true;
    }

    // Back button: return to previous view
    function onBack() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Clear reader lines on back to free memory
        state.readerLines = [] as Array<Dictionary>;
        state.readerScroll = 0;

        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }
}
