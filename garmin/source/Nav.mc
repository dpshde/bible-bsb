using Toybox.Lang;
using Toybox.WatchUi;

//! One view stack, one way to jump (UX critique issues 2, 4, 10).
//! Home (BookListView) is the base view. Every push/pop in the app goes through Nav so it knows
//! how many views sit above Home, and every jump to a reference resets the stack to
//! Home > ChapterGrid(book) > Reader: BACK from the reader is always the grid, then Home, and no
//! stale readers pile up in memory. One-chapter books skip the grid (Home > Reader), like openBook.
module Nav {
    var depth as Lang.Number = 0; // views above Home
    var readers as Lang.Array = [] as Lang.Array; // per pushed view: is it a reader (openRefOver)

    // POKE: SLIDE — one direction for the whole app: in from the right, out to the right.
    const IN = WatchUi.SLIDE_LEFT;
    const OUT = WatchUi.SLIDE_RIGHT;

    function push(view as WatchUi.Views, delegate as WatchUi.InputDelegates, t as WatchUi.SlideType) as Void {
        depth++;
        readers.add(view instanceof ReaderView);
        WatchUi.pushView(view, UiMenu.delegateFor(view, delegate), t);
    }

    //! Replace the top view (same depth). Lists go through here so a FastMenu keeps its keys.
    function swap(view as WatchUi.Views, delegate as WatchUi.InputDelegates, t as WatchUi.SlideType) as Void {
        WatchUi.switchToView(view, UiMenu.delegateFor(view, delegate), t);
    }

    //! Pop the top view. At Home this exits the app (same as before).
    function pop(t as WatchUi.SlideType) as Void {
        if (Perf.navT == 0) {
            Perf.nav("back");
        }
        if (depth > 0) {
            depth--;
        }
        if (readers.size() > 0) {
            readers = readers.slice(0, readers.size() - 1);
        }
        WatchUi.popView(t);
    }

    function toHome() as Void {
        while (depth > 0) {
            pop(WatchUi.SLIDE_IMMEDIATE);
        }
    }

    //! Open a reference (verse 0 or 1 = chapter start). `animate` false: no slide (app launch).
    function openRef(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number, animate as Lang.Boolean) as Void {
        toHome();
        AppState.selectedBook = book;
        AppState.selectedChapter = chapter;
        LastReadApp.resumeVerse = verse > 1 ? verse : 0;
        LastReadApp.pending = [book, chapter, verse > 1 ? verse : 1];
        if (Books.chapterCount(book) > 1) {
            push(new ChapterGridView(), new ChapterGridDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
        ReaderView.openFor(book, chapter, animate ? IN : WatchUi.SLIDE_IMMEDIATE);
    }

    //! 0.9.8 (Dylan): open a reference ON TOP of the list it was picked from (Bookmarks, a
    //! merged range's verses), so BACK from the reader returns to that list at the same row.
    //! The reader's "Jump to chapter" then opens the grid (Nav.openBook) instead of popping.
    function openRefOver(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Void {
        if (readers.indexOf(true) >= 0) {
            // A reader is already under this list (Bookmarks opened from the reader menu):
            // reset to Home > Grid > Reader rather than stacking a second reader.
            openRef(book, chapter, verse, true);
            return;
        }
        AppState.selectedBook = book;
        AppState.selectedChapter = chapter;
        LastReadApp.resumeVerse = verse > 1 ? verse : 0;
        LastReadApp.pending = [book, chapter, verse > 1 ? verse : 1];
        ReaderView.openOver = true;
        ReaderView.openFor(book, chapter, IN);
    }

    //! Open a book's chapter grid from a list (Testament, Go to…): Home > Grid(book).
    function openBook(book as Lang.Number) as Void {
        toHome();
        PickList.openBook(book);
    }

    //! Set by getInitialView when there is a last-read position: Home's first onShow builds
    //! Home > Grid > Reader with no animation (launch and glance land in the reader).
    var launchRef as Lang.Array or Null = null;

    function takeLaunch() as Void {
        var r = launchRef;
        launchRef = null;
        if (r != null) {
            openRef(r[0] as Lang.Number, r[1] as Lang.Number, r[2] as Lang.Number, false);
        }
    }
}
