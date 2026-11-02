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
        Palette.applyBackground(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        var y = RoundLayout.edgeMargin(w, h);
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        RoundLayout.drawCenteredInChord(dc, y, "Testament", Graphics.FONT_TINY);
        y += dc.getFontHeight(Graphics.FONT_TINY) + 8;
        var rowH = dc.getFontHeight(Graphics.FONT_SMALL) + 8;
        var i;
        for (i = 0; i < Genres.TESTAMENT_COUNT; i++) {
            var label = Genres.TESTAMENT_LABELS[i];
            var midY = y + rowH / 2;
            var left = RoundLayout.chordLeft(midY, w, h);
            var cw = RoundLayout.chordWidth(midY, w, h);
            if (i == focus) {
                dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_FG);
                dc.fillRectangle(left, y, cw, rowH - 2);
                dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(w / 2, y + 3, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);
            y += rowH;
        }
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

    function onSelect() as Lang.Boolean {
        WatchUi.pushView(
            new GenreListView(view().focus),
            new GenreListDelegate(view().focus),
            WatchUi.SLIDE_LEFT);
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
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Palette.applyBackground(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        var y = RoundLayout.edgeMargin(w, h);
        var title = testament == 0 ? "Old Testament" : "New Testament";
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        RoundLayout.drawCenteredInChord(dc, y, title, Graphics.FONT_TINY);
        y += dc.getFontHeight(Graphics.FONT_TINY) + 8;
        var rowH = dc.getFontHeight(Graphics.FONT_SMALL) + 6;
        var bottom = h - RoundLayout.edgeMargin(w, h);
        var i;
        for (i = 0; i < genreIndexes.size(); i++) {
            if (y + rowH > bottom) {
                break;
            }
            var gi = genreIndexes[i] as Lang.Number;
            var label = Genres.genreName(gi);
            var midY = y + rowH / 2;
            var left = RoundLayout.chordLeft(midY, w, h);
            var cw = RoundLayout.chordWidth(midY, w, h);
            if (i == focus) {
                dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_FG);
                dc.fillRectangle(left, y, cw, rowH - 2);
                dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(w / 2, y + 2, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);
            y += rowH;
        }
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

    function onSelect() as Lang.Boolean {
        var v = view();
        var gi = v.genreIndexes[v.focus] as Lang.Number;
        WatchUi.pushView(new GenreBookListView(gi), new GenreBookListDelegate(gi), WatchUi.SLIDE_LEFT);
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

class GenreBookListView extends WatchUi.View {
    var genreIdx as Lang.Number;
    var bookIndexes as Lang.Array;
    var focus as Lang.Number = 0;

    function initialize(genreIdx as Lang.Number) {
        View.initialize();
        me.genreIdx = genreIdx;
        me.bookIndexes = Genres.booksForGenre(genreIdx);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Palette.applyBackground(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        var y = RoundLayout.edgeMargin(w, h);
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        RoundLayout.drawCenteredInChord(dc, y, Genres.genreName(genreIdx), Graphics.FONT_TINY);
        y += dc.getFontHeight(Graphics.FONT_TINY) + 8;
        var rowH = dc.getFontHeight(Graphics.FONT_SMALL) + 6;
        var bottom = h - RoundLayout.edgeMargin(w, h);
        var i;
        for (i = 0; i < bookIndexes.size(); i++) {
            if (y + rowH > bottom) {
                break;
            }
            var bi = bookIndexes[i] as Lang.Number;
            var label = Books.name(bi);
            var midY = y + rowH / 2;
            var left = RoundLayout.chordLeft(midY, w, h);
            var cw = RoundLayout.chordWidth(midY, w, h);
            if (i == focus) {
                dc.setColor(Palette.FOCUS_BG, Palette.FOCUS_FG);
                dc.fillRectangle(left, y, cw, rowH - 2);
                dc.setColor(Palette.FOCUS_FG, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(w / 2, y + 2, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);
            y += rowH;
        }
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

    function onSelect() as Lang.Boolean {
        var v = view();
        var bi = v.bookIndexes[v.focus] as Lang.Number;
        AppState.selectedBook = bi;
        AppState.selectedChapter = 1;
        // Spike defaults for books with non-1 start content.
        if (bi == 42) {
            AppState.selectedChapter = 3;
        } else if (bi == 38) {
            AppState.selectedChapter = 4;
        }
        WatchUi.pushView(new ChapterGridView(), new ChapterGridDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
