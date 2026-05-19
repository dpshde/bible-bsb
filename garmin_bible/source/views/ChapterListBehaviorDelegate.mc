using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class ChapterListBehaviorDelegate extends Ui.BehaviorDelegate {
    var view as Ui.View;

    function initialize(v as Ui.View) {
        BehaviorDelegate.initialize();
        view = v;
    }

    // Up button: move selection up by 5 chapters (one row)
    function onPreviousPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var cols = 5;

        if (state.chapter > cols) {
            state.chapter = state.chapter - cols;
        }
        // Clamp at first row (no wrap)

        Ui.requestUpdate();
        return true;
    }

    // Down button: move selection down by 5 chapters (one row)
    function onNextPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var maxChapter = BibleBooks.getChapterCount(state.bookIndex);
        var cols = 5;

        if (state.chapter + cols <= maxChapter) {
            state.chapter = state.chapter + cols;
        } else if (state.chapter < maxChapter) {
            state.chapter = maxChapter;
        }
        // Clamp at last chapter (no wrap)

        Ui.requestUpdate();
        return true;
    }

    // Left button: decrement chapter by 1
    function onPreviousMode() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        if (state.chapter > 1) {
            state.chapter = state.chapter - 1;
        }

        Ui.requestUpdate();
        return true;
    }

    // Right button: increment chapter by 1
    function onNextMode() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var maxChapter = BibleBooks.getChapterCount(state.bookIndex);

        if (state.chapter < maxChapter) {
            state.chapter = state.chapter + 1;
        }

        Ui.requestUpdate();
        return true;
    }

    // Enter/Select button: push VerseSelectView
    function onSelect() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        // Reset verse select state to defaults
        state.verseSelectMode = 0; // All verses
        state.startVerse = 1;
        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        if (maxVerse <= 0) {
            maxVerse = 1;
        }
        state.endVerse = maxVerse;

        var verseView = new VerseSelectView();
        var verseDelegate = new VerseSelectBehaviorDelegate(verseView);
        Ui.pushView(verseView, verseDelegate, Ui.SLIDE_LEFT);
        return true;
    }

    // Tap handler for touch devices: treat as select
    function onTap(tapEvent as Ui.ClickEvent) as Boolean {
        if (!BibleLayout.hasTouchScreen()) {
            return false;
        }
        return onSelect();
    }

    // Back button: return to BookList
    function onBack() as Boolean {
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }
}
