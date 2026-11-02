using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class BookListView extends WatchUi.View {
    var focus as Lang.Number = 0; // book index 0..65 (Genesis..Revelation)
    // Hit-test cache from last onUpdate
    var _rowTop as Lang.Number = 0;
    var _rowH as Lang.Number = 0;
    var _rowCount as Lang.Number = 0;
    var _labels as Lang.Array or Null = null;

    function initialize() {
        View.initialize();
        focus = AppState.selectedBook; // last-read book (LastReadApp.restore)
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var t0 = Perf.start();
        onUpdateImpl(dc);
        Perf.end("books", t0);
    }

    function onUpdateImpl(dc as Graphics.Dc) as Void {
        // Flipper home "< All >": every book, scrolling round list (full BSB bundled).
        // PERF: label array built once (same array -> PickList layout cache hits).
        if (_labels == null) {
            var labels = [] as Lang.Array;
            var i;
            for (i = 0; i < Books.BOOK_COUNT; i++) {
                labels.add(Books.name(i));
            }
            _labels = labels;
        }
        _rowCount = Books.BOOK_COUNT;
        focus = PickList.takeFocus(focus);
        PickList.draw(dc, "Bible BSB", _labels as Lang.Array, focus);
    }

    function rowAtY(y as Lang.Number) as Lang.Number {
        return PickList.indexAtY(y, Books.BOOK_COUNT);
    }

    function openFocusedBook() as Void {
        PickList.openBook(focus);
    }
}

class BookListDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function view() as BookListView {
        return WatchUi.getCurrentView()[0] as BookListView;
    }

    function onNextPage() as Lang.Boolean {
        if (PickList.swallowSwipe()) {
            return true;
        }
        if (TouchGuard.consumePage()) {
            return true;
        }
        var v = view();
        v.focus = (v.focus + 1) % Books.BOOK_COUNT;
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        if (PickList.swallowSwipe()) {
            return true;
        }
        if (TouchGuard.consumePage()) {
            return true;
        }
        var v = view();
        v.focus = (v.focus + Books.BOOK_COUNT - 1) % Books.BOOK_COUNT;
        WatchUi.requestUpdate();
        return true;
    }

    // TAP FIX: on touch watches a screen tap is ALSO mapped to the onSelect behavior
    // (before onTap), which opened the highlighted row instead of the tapped one.
    // onSelect therefore never acts: button Enter arrives via onKey, taps via onTap.
    function onSelect() as Lang.Boolean {
        return false;
    }

    function onKey(evt as WatchUi.KeyEvent) as Lang.Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            return activate();
        }
        return false;
    }

    function activate() as Lang.Boolean {
        view().openFocusedBook();
        return true;
    }

    function onDrag(evt as WatchUi.DragEvent) as Lang.Boolean {
        return PickList.onDrag(evt);
    }

    function onTap(evt) as Lang.Boolean {
        var coords = evt.getCoordinates();
        var v = view();
        var idx = v.rowAtY(coords[1]);
        if (idx >= 0) {
            v.focus = idx;
            v.openFocusedBook();
        }
        return true;
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        if (PickList.swallowSwipe() && (dir == WatchUi.SWIPE_UP || dir == WatchUi.SWIPE_DOWN)) {
            return true; // the drag already moved the list
        }
        if (dir == WatchUi.SWIPE_LEFT) {
            // Flipper home Right = Filter: swipe left opens all 22 filters.
            var fv = new FilterGridView();
            WatchUi.pushView(fv, new FilterGridDelegate(fv), WatchUi.SLIDE_LEFT);
            return true;
        }
        if (dir == WatchUi.SWIPE_UP) {
            TouchGuard.markPage();
            var v = view();
            v.focus = (v.focus + 1) % Books.BOOK_COUNT;
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            TouchGuard.markPage();
            var v2 = view();
            v2.focus = (v2.focus + Books.BOOK_COUNT - 1) % Books.BOOK_COUNT;
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            TouchGuard.markBack();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onMenu() as Lang.Boolean {
        // Flipper home: Left = Collection, Right = Testament / Filter -> one Browse Menu2.
        HomeMenu2Delegate.open();
        return true;
    }

    function onBack() as Lang.Boolean {
        if (TouchGuard.consumeBack()) {
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
