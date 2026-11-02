using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Testament → Genre → books alternate entry (Flipper 51d0ce4). Snake grid stays default.
//! POKE: whether Browse-by-Testament should become the default entry path.

class TestamentListView extends WatchUi.View {
    var focus as Lang.Number = 0;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        PickList.draw(dc, "Testament", Genres.TESTAMENT_LABELS, focus);
    }
}

class TestamentListDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function view() as TestamentListView {
        return WatchUi.getCurrentView()[0] as TestamentListView;
    }

    function onNextPage() as Lang.Boolean {
        var v = view();
        v.focus = (v.focus + 1) % Genres.TESTAMENT_COUNT;
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        var v = view();
        v.focus = (v.focus + Genres.TESTAMENT_COUNT - 1) % Genres.TESTAMENT_COUNT;
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
        WatchUi.pushView(
            new GenreListView(view().focus),
            new GenreListDelegate(view().focus),
            WatchUi.SLIDE_LEFT);
        return true;
    }

    //! Tap: hit-test the rows PickList.draw just laid out; open the TAPPED row.
    function onTap(evt as WatchUi.ClickEvent) as Lang.Boolean {
        var idx = PickList.indexAtY(evt.getCoordinates()[1], 2);
        if (idx >= 0) {
            view().focus = idx;
            activate();
        }
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

class GenreListView extends WatchUi.View {
    var testament as Lang.Number;
    var genreIndexes as Lang.Array;
    var focus as Lang.Number = 0;

    function initialize(testament as Lang.Number) {
        View.initialize();
        me.testament = testament;
        me.genreIndexes = Genres.genresForTestament(testament);
        // PERF: labels built once (stable array -> PickList layout cache).
        _labels = [] as Lang.Array;
        var i;
        for (i = 0; i < genreIndexes.size(); i++) {
            _labels.add(Genres.genreName(genreIndexes[i] as Lang.Number));
        }
    }

    var _labels as Lang.Array = [] as Lang.Array;

    function onUpdate(dc as Graphics.Dc) as Void {
        PickList.draw(dc, testament == 0 ? "Old Testament" : "New Testament", _labels, focus);
    }
}

class GenreListDelegate extends WatchUi.BehaviorDelegate {
    var _testament as Lang.Number;

    function initialize(testament as Lang.Number) {
        BehaviorDelegate.initialize();
        _testament = testament;
    }

    function view() as GenreListView {
        return WatchUi.getCurrentView()[0] as GenreListView;
    }

    function onNextPage() as Lang.Boolean {
        var v = view();
        if (v.genreIndexes.size() == 0) {
            return true;
        }
        v.focus = (v.focus + 1) % v.genreIndexes.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        var v = view();
        if (v.genreIndexes.size() == 0) {
            return true;
        }
        v.focus = (v.focus + v.genreIndexes.size() - 1) % v.genreIndexes.size();
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
        var v = view();
        var gi = v.genreIndexes[v.focus] as Lang.Number;
        var books = Genres.booksForGenre(gi);
        if (books.size() == 1) {
            // Flipper: single-book genre (Acts, Revelation) skips the 1-row book list.
            PickList.openBook(books[0] as Lang.Number);
            return true;
        }
        WatchUi.pushView(new GenreBookListView(gi), new GenreBookListDelegate(gi), WatchUi.SLIDE_LEFT);
        return true;
    }

    //! Tap: hit-test the rows PickList.draw just laid out; open the TAPPED row.
    function onTap(evt as WatchUi.ClickEvent) as Lang.Boolean {
        var idx = PickList.indexAtY(evt.getCoordinates()[1], view().genreIndexes.size());
        if (idx >= 0) {
            view().focus = idx;
            activate();
        }
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

class GenreBookListView extends WatchUi.View {
    var _labels as Lang.Array or Null = null;
    var genreIdx as Lang.Number;
    var bookIndexes as Lang.Array;
    var focus as Lang.Number = 0;

    function initialize(genreIdx as Lang.Number) {
        View.initialize();
        me.genreIdx = genreIdx;
        me.bookIndexes = Genres.booksForGenre(genreIdx);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        // Flipper header_name ("< OT History >") without the L/R chevrons.
        if (_labels == null) {
            _labels = PickList.bookLabels(bookIndexes); // PERF: once
        }
        PickList.draw(dc, Genres.headerName(genreIdx), _labels as Lang.Array, focus);
    }
}

class GenreBookListDelegate extends WatchUi.BehaviorDelegate {
    var _genreIdx as Lang.Number;

    function initialize(genreIdx as Lang.Number) {
        BehaviorDelegate.initialize();
        _genreIdx = genreIdx;
    }

    function view() as GenreBookListView {
        return WatchUi.getCurrentView()[0] as GenreBookListView;
    }

    function onNextPage() as Lang.Boolean {
        var v = view();
        if (v.bookIndexes.size() == 0) {
            return true;
        }
        v.focus = (v.focus + 1) % v.bookIndexes.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        var v = view();
        if (v.bookIndexes.size() == 0) {
            return true;
        }
        v.focus = (v.focus + v.bookIndexes.size() - 1) % v.bookIndexes.size();
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
        var v = view();
        PickList.openBook(v.bookIndexes[v.focus] as Lang.Number);
        return true;
    }

    //! Tap: hit-test the rows PickList.draw just laid out; open the TAPPED row.
    function onTap(evt as WatchUi.ClickEvent) as Lang.Boolean {
        var idx = PickList.indexAtY(evt.getCoordinates()[1], view().bookIndexes.size());
        if (idx >= 0) {
            view().focus = idx;
            activate();
        }
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
