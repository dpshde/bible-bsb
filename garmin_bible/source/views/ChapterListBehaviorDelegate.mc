using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class ChapterListBehaviorDelegate extends Ui.BehaviorDelegate {
    var view as Ui.View;

    function initialize(v as Ui.View) {
        BehaviorDelegate.initialize();
        view = v;
    }

    // Up button: move backward one chapter. The grid draws in a snake path,
    // so incremental movement stays adjacent instead of jumping rows.
    function onPreviousPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        if (state.chapter > 1) {
            state.chapter = state.chapter - 1;
        }

        Ui.requestUpdate();
        return true;
    }

    // Down button: move forward one chapter. The visual snake order keeps the
    // next chapter next to the current one at row boundaries.
    function onNextPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var maxChapter = BibleBooks.getChapterCount(state.bookIndex);

        if (state.chapter < maxChapter) {
            state.chapter = state.chapter + 1;
        }

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
