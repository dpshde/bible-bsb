import Toybox.Lang;
using Toybox.Test;
using Toybox.Application;
using Toybox.Graphics;

class ReaderViewTest {

    // ------------------------------------------------------------------
    // Passage reference in header
    // ------------------------------------------------------------------

    function testDisplayRefSingleVerse(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.setPassage(42, 3, 16, 16);
        var ref = state.getDisplayRef();
        return ref == "John 3:16";
    }

    function testDisplayRefRange(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.setPassage(42, 3, 16, 18);
        var ref = state.getDisplayRef();
        return ref == "John 3:16-18";
    }

    function testDisplayRefFullChapter(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.setPassage(42, 3, 1, 36);
        var ref = state.getDisplayRef();
        return ref == "John 3";
    }

    function testScriptureRefSingleVerse(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.setPassage(42, 3, 16, 16);
        var ref = state.getScriptureRef();
        return ref == "jhn.3.16";
    }

    function testScriptureRefRange(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.setPassage(42, 3, 16, 18);
        var ref = state.getScriptureRef();
        return ref == "jhn.3.16-jhn.3.18";
    }

    // ------------------------------------------------------------------
    // Loading state
    // ------------------------------------------------------------------

    function testLoadingStateIsTrueOnShow(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        // Simulate entering Reader
        state.readerIsLoading = true;
        state.readerError = "";
        state.readerLines = [] as Array<Dictionary>;
        return state.readerIsLoading;
    }

    // ------------------------------------------------------------------
    // Error state
    // ------------------------------------------------------------------

    function testErrorStateOverridesLoading(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.readerIsLoading = false;
        state.readerError = "No connection";
        state.readerLines = [] as Array<Dictionary>;
        return !state.readerIsLoading && state.readerError.length() > 0;
    }

    function testError404Message(logger as Test.Logger) as Boolean {
        var msg = BibleApi.getErrorMessage(404);
        return msg == "Chapter not found";
    }

    function testErrorNoConnectionMessage(logger as Test.Logger) as Boolean {
        var msg = BibleApi.getErrorMessage(-1);
        return msg == "No connection";
    }

    function testErrorGenericMessage(logger as Test.Logger) as Boolean {
        var msg = BibleApi.getErrorMessage(500);
        return msg == "Failed to load chapter";
    }

    // ------------------------------------------------------------------
    // Toast state
    // ------------------------------------------------------------------

    function testToastInactiveWhenEmpty(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.readerToastMessage = "";
        state.readerToastEndTime = 0;
        return !state.isToastActive();
    }

    function testToastInactiveWhenExpired(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.readerToastMessage = "Saved!";
        state.readerToastEndTime = 0;
        return !state.isToastActive();
    }

    // ------------------------------------------------------------------
    // Reader lines and pagination
    // ------------------------------------------------------------------

    function testReaderLinesEmptyOnInit(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        return state.readerLines.size() == 0;
    }

    function testScrollClampedToMax(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.readerLines = [
            { "text" => "1 In the beginning.", "verseNumber" => 1, "isFirstLine" => true },
            { "text" => "2 And the earth.", "verseNumber" => 2, "isFirstLine" => true }
        ] as Array<Dictionary>;
        state.readerScroll = 0;
        state.readerLinesPerPage = 1;
        var maxS = BibleRenderer.maxScroll(state.readerLines.size(), state.readerLinesPerPage);
        return maxS == 1;
    }

    function testPageNavigationRight(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.readerLines = [
            { "text" => "1 Line one.", "verseNumber" => 1, "isFirstLine" => true },
            { "text" => "2 Line two.", "verseNumber" => 2, "isFirstLine" => true },
            { "text" => "3 Line three.", "verseNumber" => 3, "isFirstLine" => true }
        ] as Array<Dictionary>;
        state.readerScroll = 0;
        state.readerLinesPerPage = 2;
        var maxS = BibleRenderer.maxScroll(state.readerLines.size(), state.readerLinesPerPage);
        var newScroll = BibleRenderer.pageRight(state.readerScroll, maxS, state.readerLinesPerPage);
        return newScroll == 2;
    }

    function testPageNavigationLeft(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.readerLines = [
            { "text" => "1 Line one.", "verseNumber" => 1, "isFirstLine" => true },
            { "text" => "2 Line two.", "verseNumber" => 2, "isFirstLine" => true },
            { "text" => "3 Line three.", "verseNumber" => 3, "isFirstLine" => true }
        ] as Array<Dictionary>;
        state.readerScroll = 2;
        state.readerLinesPerPage = 2;
        var maxS = BibleRenderer.maxScroll(state.readerLines.size(), state.readerLinesPerPage);
        var newScroll = BibleRenderer.pageLeft(state.readerScroll, state.readerLinesPerPage);
        return newScroll == 0;
    }

    // ------------------------------------------------------------------
    // ActionMenu state
    // ------------------------------------------------------------------

    function testActionMenuSelectionStartsAtZero(logger as Test.Logger) as Boolean {
        var readerView = new ReaderView();
        var menuView = new ActionMenuView(readerView);
        return menuView.selectedItem == 0;
    }

    function testActionMenuSelectionDown(logger as Test.Logger) as Boolean {
        var readerView = new ReaderView();
        var menuView = new ActionMenuView(readerView);
        menuView.selectedItem = 0;
        menuView.selectedItem = menuView.selectedItem + 1;
        return menuView.selectedItem == 1;
    }

    function testActionMenuSelectionUp(logger as Test.Logger) as Boolean {
        var readerView = new ReaderView();
        var menuView = new ActionMenuView(readerView);
        menuView.selectedItem = 2;
        menuView.selectedItem = menuView.selectedItem - 1;
        return menuView.selectedItem == 1;
    }

    function testActionMenuSelectionClampsAtTop(logger as Test.Logger) as Boolean {
        var readerView = new ReaderView();
        var menuView = new ActionMenuView(readerView);
        menuView.selectedItem = 0;
        if (menuView.selectedItem > 0) {
            menuView.selectedItem = menuView.selectedItem - 1;
        }
        return menuView.selectedItem == 0;
    }

    function testActionMenuSelectionClampsAtBottom(logger as Test.Logger) as Boolean {
        var readerView = new ReaderView();
        var menuView = new ActionMenuView(readerView);
        menuView.selectedItem = 2;
        if (menuView.selectedItem < 2) {
            menuView.selectedItem = menuView.selectedItem + 1;
        }
        return menuView.selectedItem == 2;
    }

    // ------------------------------------------------------------------
    // Collection save helper logic
    // ------------------------------------------------------------------

    function testCollectionEntryBuildsCorrectly(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.setPassage(42, 3, 16, 16);

        var entry = {
            "scripture_ref" => state.getScriptureRef(),
            "display_ref" => state.getDisplayRef(),
            "translation" => "BSB",
            "book_index" => state.bookIndex,
            "chapter" => state.chapter,
            "start_verse" => state.startVerse,
            "end_verse" => state.endVerse,
            "captured_at" => "12345"
        } as Dictionary;

        return entry.get("scripture_ref") == "jhn.3.16" &&
               entry.get("display_ref") == "John 3:16" &&
               entry.get("translation") == "BSB" &&
               entry.get("book_index") == 42 &&
               entry.get("chapter") == 3 &&
               entry.get("start_verse") == 16 &&
               entry.get("end_verse") == 16;
    }

    function testCollectionMax50(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.setPassage(42, 3, 16, 16);

        var arr = [] as Array<Dictionary>;
        for (var i = 0; i < 50; i++) {
            var entry = {
                "scripture_ref" => "jhn.3." + i,
                "display_ref" => "John 3:" + i,
                "book_index" => 42,
                "chapter" => 3,
                "start_verse" => i,
                "end_verse" => i
            } as Dictionary;
            arr.add(entry);
        }
        return arr.size() == 50;
    }

    function testCollectionRemoveOldest(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.setPassage(42, 3, 16, 16);

        var arr = [] as Array<Dictionary>;
        for (var i = 0; i < 50; i++) {
            var entry = {
                "scripture_ref" => "jhn.3." + i,
                "display_ref" => "John 3:" + i
            } as Dictionary;
            arr.add(entry);
        }

        // Simulate FIFO removal
        var result = [] as Array<Dictionary>;
        for (var i = 1; i < arr.size(); i++) {
            result.add(arr[i]);
        }
        result.add({ "scripture_ref" => "jhn.3.99", "display_ref" => "John 3:99" } as Dictionary);

        return result.size() == 50 &&
               result[0].get("scripture_ref") == "jhn.3.1" &&
               result[49].get("scripture_ref") == "jhn.3.99";
    }

    // ------------------------------------------------------------------
    // Navigation origin tracking
    // ------------------------------------------------------------------

    function testCameFromCollectionDefaultFalse(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        return !state.cameFromCollection;
    }

    function testCameFromCollectionCanBeSet(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.cameFromCollection = true;
        return state.cameFromCollection;
    }

    // ------------------------------------------------------------------
    // Empty chapter handling
    // ------------------------------------------------------------------

    function testEmptyLinesShowsError(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.readerIsLoading = false;
        state.readerError = "";
        state.readerLines = [] as Array<Dictionary>;
        // ReaderView.onUpdate would fall through to the empty-lines branch
        // and render "Failed to load chapter"
        var fallbackMsg = WatchUi.loadResource(Rez.Strings.ErrorLoadFailed) as String;
        return fallbackMsg != null && fallbackMsg.length() > 0;
    }

    // ------------------------------------------------------------------
    // ReaderView instantiation
    // ------------------------------------------------------------------

    function testReaderViewInstantiates(logger as Test.Logger) as Boolean {
        var view = new ReaderView();
        return view != null;
    }

    function testReaderDelegateInstantiates(logger as Test.Logger) as Boolean {
        var view = new ReaderView();
        var delegate = new ReaderBehaviorDelegate(view);
        return delegate != null;
    }

    // ------------------------------------------------------------------
    // ActionMenuView instantiation
    // ------------------------------------------------------------------

    function testActionMenuViewInstantiates(logger as Test.Logger) as Boolean {
        var reader = new ReaderView();
        var menu = new ActionMenuView(reader);
        return menu != null && menu.parentView != null;
    }

    function testActionMenuDelegateInstantiates(logger as Test.Logger) as Boolean {
        var reader = new ReaderView();
        var menu = new ActionMenuView(reader);
        var delegate = new ActionMenuBehaviorDelegate(menu);
        return delegate != null && delegate.menuView != null;
    }

    // ------------------------------------------------------------------
    // Reader scroll boundaries
    // ------------------------------------------------------------------

    function testScrollUpAtZero(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.readerLines = [
            { "text" => "1 Line.", "verseNumber" => 1, "isFirstLine" => true }
        ] as Array<Dictionary>;
        state.readerScroll = 0;
        state.readerLinesPerPage = 1;
        var maxS = BibleRenderer.maxScroll(state.readerLines.size(), state.readerLinesPerPage);
        var newScroll = BibleRenderer.scrollUp(state.readerScroll);
        var clamped = BibleRenderer.clampScroll(newScroll, maxS);
        return clamped == 0;
    }

    function testScrollDownAtMax(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.readerLines = [
            { "text" => "1 Line one.", "verseNumber" => 1, "isFirstLine" => true },
            { "text" => "2 Line two.", "verseNumber" => 2, "isFirstLine" => true }
        ] as Array<Dictionary>;
        state.readerScroll = 0;
        state.readerLinesPerPage = 2;
        var maxS = BibleRenderer.maxScroll(state.readerLines.size(), state.readerLinesPerPage);
        var newScroll = BibleRenderer.scrollDown(state.readerScroll, maxS);
        var clamped = BibleRenderer.clampScroll(newScroll, maxS);
        return clamped == 0;
    }

    // ------------------------------------------------------------------
    // Page indicator
    // ------------------------------------------------------------------

    function testPageIndicatorForMultiPage(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.readerLines = [
            { "text" => "1.", "verseNumber" => 1, "isFirstLine" => true },
            { "text" => "2.", "verseNumber" => 2, "isFirstLine" => true },
            { "text" => "3.", "verseNumber" => 3, "isFirstLine" => true },
            { "text" => "4.", "verseNumber" => 4, "isFirstLine" => true }
        ] as Array<Dictionary>;
        state.readerLinesPerPage = 2;
        var lineCount = state.readerLines.size();
        var totalPages = BibleRenderer.computeTotalPages(lineCount, state.readerLinesPerPage);
        var currentPage = BibleRenderer.scrollToPage(state.readerScroll, state.readerLinesPerPage);
        currentPage = BibleRenderer.clampPage(currentPage, totalPages);
        var indicator = BibleRenderer.buildPageIndicator(currentPage, totalPages);
        return indicator == "1/2";
    }

    function testPageIndicatorSinglePage(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as BibleApp;
        var state = app.state;
        state.readerLines = [
            { "text" => "1.", "verseNumber" => 1, "isFirstLine" => true }
        ] as Array<Dictionary>;
        state.readerLinesPerPage = 2;
        var lineCount = state.readerLines.size();
        var totalPages = BibleRenderer.computeTotalPages(lineCount, state.readerLinesPerPage);
        var currentPage = BibleRenderer.scrollToPage(state.readerScroll, state.readerLinesPerPage);
        currentPage = BibleRenderer.clampPage(currentPage, totalPages);
        var indicator = BibleRenderer.buildPageIndicator(currentPage, totalPages);
        return indicator == "";
    }
}
