using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class VerseSelectBehaviorDelegate extends Ui.BehaviorDelegate {
    var view as Ui.View;

    function initialize(v as Ui.View) {
        BehaviorDelegate.initialize();
        view = v;
    }

    // Up button: move mode up (End -> Start -> All)
    function onPreviousPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        if (state.verseSelectMode == 2) {
            state.verseSelectMode = 1; // End -> Start
        } else if (state.verseSelectMode == 1) {
            state.verseSelectMode = 0; // Start -> All
        }
        // All (0) stays All

        Ui.requestUpdate();
        return true;
    }

    // Down button: move mode down (All -> Start -> End)
    function onNextPage() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        if (state.verseSelectMode == 0) {
            state.verseSelectMode = 1; // All -> Start
        } else if (state.verseSelectMode == 1) {
            state.verseSelectMode = 2; // Start -> End
        }
        // End (2) stays End

        Ui.requestUpdate();
        return true;
    }

    // Left button: decrement verse number
    function onPreviousMode() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        if (state.verseSelectMode == 1) {
            // Start mode: decrement start verse (min=1)
            if (state.startVerse > 1) {
                state.startVerse = state.startVerse - 1;
            }
        } else if (state.verseSelectMode == 2) {
            // End mode: decrement end verse (min=startVerse)
            if (state.endVerse > state.startVerse) {
                state.endVerse = state.endVerse - 1;
            }
        }

        Ui.requestUpdate();
        return true;
    }

    // Right button: increment verse number
    function onNextMode() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        if (maxVerse <= 0) {
            maxVerse = 40;
        }

        if (state.verseSelectMode == 1) {
            // Start mode: increment start verse, auto-bump end if needed
            if (state.startVerse < maxVerse) {
                state.startVerse = state.startVerse + 1;
                if (state.endVerse < state.startVerse) {
                    state.endVerse = state.startVerse;
                }
            }
        } else if (state.verseSelectMode == 2) {
            // End mode: increment end verse (clamped to actual_max)
            if (state.endVerse < maxVerse) {
                state.endVerse = state.endVerse + 1;
            }
        }

        Ui.requestUpdate();
        return true;
    }

    // Enter/Select button: load Reader (or show placeholder)
    function onSelect() as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;

        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        if (maxVerse <= 0) {
            maxVerse = 40;
        }

        if (state.verseSelectMode == 0) {
            // "All verses" — load full chapter
            state.startVerse = 1;
            state.endVerse = maxVerse;
        }
        // For mode 1 or 2, startVerse/endVerse are already set by the user

        // Store passage in state
        state.setPassage(state.bookIndex, state.chapter, state.startVerse, state.endVerse);
        state.cameFromCollection = false;

        // Push ReaderView — placeholder since Reader is a future feature
        var readerView = new ReaderView();
        var readerDelegate = new ReaderBehaviorDelegate(readerView);
        Ui.pushView(readerView, readerDelegate, Ui.SLIDE_LEFT);
        return true;
    }

    // Back button: return to ChapterList
    function onBack() as Boolean {
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }
}
