using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Home rows: 66 books, then one "Menu & Settings" row (v6: the app menu is reachable
//! without knowing the hold-UP / MENU gesture). Up from Genesis wraps straight onto it.
const HOME_ROWS = 67;
const HOME_MENU_ROW = 66;

class BookListView extends WatchUi.View {
    var focus as Lang.Number = 0; // 0..65 = book (Genesis..Revelation), 66 = menu row
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
            labels.add(PickList.MENU_ROW_LABEL);
            _labels = labels;
        }
        _rowCount = HOME_ROWS;
        focus = PickList.takeFocus(focus, _labels as Lang.Array);
        PickList.draw(dc, "Bible BSB", _labels as Lang.Array, focus);
    }

    function onHide() as Void {
        PickList.stopWarm();
    }

    function rowAtY(y as Lang.Number) as Lang.Number {
        return PickList.indexAtY(y, HOME_ROWS);
    }

    function openFocusedBook() as Void {
        if (focus >= Books.BOOK_COUNT) {
            HomeMenu2Delegate.open();
            return;
        }
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
        v.focus = (v.focus + 1) % HOME_ROWS;
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
        v.focus = (v.focus + HOME_ROWS - 1) % HOME_ROWS;
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
        if (coords[1] < PickList.lastTop) {
            // Touch: the "Bible BSB" title opens the app menu too.
            HomeMenu2Delegate.open();
            return true;
        }
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
            NativeLists.openFilter();
            return true;
        }
        if (dir == WatchUi.SWIPE_UP) {
            TouchGuard.markPage();
            var v = view();
            v.focus = (v.focus + 1) % HOME_ROWS;
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            TouchGuard.markPage();
            var v2 = view();
            v2.focus = (v2.focus + HOME_ROWS - 1) % HOME_ROWS;
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
        // MENU (hold UP on Enduro/Forerunner; hold the lower button on touch watches).
        // Flipper home: Left = Collection, Right = Testament / Filter -> one app menu.
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
