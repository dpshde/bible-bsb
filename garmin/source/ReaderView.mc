using Toybox.Attention;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Timer;
using Toybox.WatchUi;

class ReaderView extends WatchUi.View {
    var toast as Lang.String or Null = null;
    var _toastTimer as Timer.Timer or Null = null;
    var _laidOut as Lang.Boolean = false;
    var _bodyFont as Lang.Number = Graphics.FONT_XTINY;
    var _colLeft as Lang.Number = 0;
    var _colWidth as Lang.Number = 0;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        rebuildLines(dc);
        _laidOut = true;
    }

    function onShow() as Void {
        AppState.scroll.mode = AppState.scroll.loadMode();
    }

    function onHide() as Void {
        clearToastTimer();
    }

    function rebuildLines(dc as Graphics.Dc) as Void {
        var book = AppState.selectedBook;
        var chapter = AppState.selectedChapter;
        var w = dc.getWidth();
        var h = dc.getHeight();
        var headerFont = Graphics.FONT_TINY;
        var headerH = dc.getFontHeight(headerFont) + 8;
        var contentTop = RoundLayout.edgeMargin(w, h) + headerH;
        var contentBottom = h - RoundLayout.edgeMargin(w, h);
        var col = RoundLayout.columnRect(w, h, contentTop, contentBottom);
        _colLeft = col[:left] as Lang.Number;
        _colWidth = col[:width] as Lang.Number;

        // Wrap width: RECT uses fixed column; CENTERED_CHORD uses min chord in band.
        // POKE: RoundLayout.READER_LAYOUT switch.
        var wrapW = _colWidth;
        if (RoundLayout.READER_LAYOUT == RoundLayout.READER_LAYOUT_CENTERED_CHORD) {
            wrapW = RoundLayout.minChordInBand(contentTop + 4, contentBottom - 4, w, h);
        }

        var lines = [] as Lang.Array;
        appendChapterLines(dc, lines, book, chapter, wrapW);

        var nxt = ChapterNav.nextChapter(book, chapter);
        if (nxt != null && ContentLoader.hasChapter(nxt.book, nxt.chapter)) {
            appendDivider(lines, nxt.book, nxt.chapter);
            appendChapterLines(dc, lines, nxt.book, nxt.chapter, wrapW);
        } else if (nxt == null && ChapterNav.isBibleEnd(book, chapter)) {
            lines.add(new ScrollModel.Line(ScrollModel.KIND_END, book, chapter, 0, "— End —", false));
        }

        AppState.scroll.lines = lines;
        AppState.scroll.scrollOffset = 0;
        AppState.scroll.clampOffset();
    }

    function appendDivider(lines as Lang.Array, book as Lang.Number, chapter as Lang.Number) as Void {
        var divText = Books.name(book) + " " + chapter;
        var pad = RoundLayout.DIVIDER_PAD_LINES;
        // POKE: DIVIDER_PAD_LINES
        var i;
        for (i = 0; i < pad; i++) {
            lines.add(new ScrollModel.Line(ScrollModel.KIND_SPACER, book, chapter, 0, "", false));
        }
        lines.add(new ScrollModel.Line(ScrollModel.KIND_DIVIDER, book, chapter, 0, divText, false));
        for (i = 0; i < pad; i++) {
            lines.add(new ScrollModel.Line(ScrollModel.KIND_SPACER, book, chapter, 0, "", false));
        }
    }

    function appendChapterLines(dc as Graphics.Dc, lines as Lang.Array, book as Lang.Number,
                                chapter as Lang.Number, wrapW as Lang.Number) as Void {
        var data = ContentLoader.loadChapter(book, chapter);
        if (data == null) {
            return;
        }
        var verses = data[:verses];
        if (verses == null) {
            return;
        }
        var i;
        for (i = 0; i < verses.size(); i++) {
            var v = verses[i];
            var n = v["n"];
            var t = v["t"];
            if (n == null) {
                n = v[:n];
            }
            if (t == null) {
                t = v[:t];
            }
            var wrapped = ContentLoader.wrapVerseToWidth(
                dc, _bodyFont, n as Lang.Number, t as Lang.String, wrapW);
            var j;
            for (j = 0; j < wrapped.size(); j++) {
                var row = wrapped[j];
                lines.add(new ScrollModel.Line(
                    ScrollModel.KIND_VERSE,
                    book,
                    chapter,
                    row[:verse] as Lang.Number,
                    row[:text] as Lang.String,
                    row[:isStart] as Lang.Boolean
                ));
            }
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (!_laidOut) {
            rebuildLines(dc);
            _laidOut = true;
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var focus = AppState.scroll.focusVerse();
        var title = Books.name(focus[:book] as Lang.Number) + " " + focus[:chapter] + ":" + focus[:verse];
        var headerFont = Graphics.FONT_TINY;
        var headerY = RoundLayout.edgeMargin(w, h);

        // Header only — no permanent V/L chip (POKE: tiny icon in safe area as alternate).
        RoundLayout.drawCenteredInChord(dc, headerY, title, headerFont);

        var y = headerY + dc.getFontHeight(headerFont) + 4;
        // Rule and body share the straight column when RECT.
        var col = RoundLayout.columnRect(w, h, y + 4, h - RoundLayout.edgeMargin(w, h));
        _colLeft = col[:left] as Lang.Number;
        _colWidth = col[:width] as Lang.Number;
        dc.drawLine(_colLeft, y, _colLeft + _colWidth, y);
        y += 4;

        var lineH = dc.getFontHeight(_bodyFont) + 2;
        var bottom = col[:bottom] as Lang.Number;
        AppState.scroll.visibleCount = (bottom - y) / lineH;
        if (AppState.scroll.visibleCount < 1) {
            AppState.scroll.visibleCount = 1;
        }

        var useChord = RoundLayout.READER_LAYOUT == RoundLayout.READER_LAYOUT_CENTERED_CHORD;
        var lines = AppState.scroll.lines;
        var i;
        for (i = 0; i < AppState.scroll.visibleCount; i++) {
            var idx = AppState.scroll.scrollOffset + i;
            if (idx >= lines.size()) {
                break;
            }
            var ln = lines[idx] as ScrollModel.Line;
            var midY = y + lineH / 2;
            var left = _colLeft;
            var cw = _colWidth;
            if (useChord) {
                left = RoundLayout.chordLeft(midY, w, h);
                cw = RoundLayout.chordWidth(midY, w, h);
            }

            if (ln.kind == ScrollModel.KIND_SPACER) {
                y += lineH;
                continue;
            }
            if (ln.kind == ScrollModel.KIND_DIVIDER) {
                var ruleY1 = y + 2;
                var ruleY2 = y + lineH - 3;
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(left + 4, ruleY1, left + cw - 4, ruleY1);
                dc.drawLine(left + 4, ruleY2, left + cw - 4, ruleY2);
                dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y + 3, Graphics.FONT_TINY, ln.text, Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
            } else if (ln.kind == ScrollModel.KIND_END) {
                dc.drawText(w / 2, y, Graphics.FONT_TINY, ln.text, Graphics.TEXT_JUSTIFY_CENTER);
            } else if (useChord) {
                // CENTERED_CHORD: both edges taper — center the glyphs on the row.
                dc.setClip(left, y, cw, lineH);
                dc.drawText(w / 2, y, _bodyFont, ln.text, Graphics.TEXT_JUSTIFY_CENTER);
                dc.clearClip();
            } else {
                // RECT default: straight left edge inside the column.
                dc.setClip(_colLeft, y, _colWidth, lineH);
                dc.drawText(_colLeft, y, _bodyFont, ln.text, Graphics.TEXT_JUSTIFY_LEFT);
                dc.clearClip();
            }
            y += lineH;
        }

        if (toast != null) {
            RoundLayout.drawToastPill(dc, toast);
        }
    }

    function showToast(message as Lang.String) as Void {
        toast = message;
        clearToastTimer();
        _toastTimer = new Timer.Timer();
        // POKE: RoundLayout.TOAST_MS
        _toastTimer.start(method(:onToastExpired), RoundLayout.TOAST_MS, false);
        WatchUi.requestUpdate();
    }

    //! Brief centered "Line scroll" / "Verse scroll" when mode changes — no corner letter.
    function showModeBanner() as Void {
        // POKE: MODE_BANNER_ONLY vs small persistent icon.
        var label = AppState.scroll.mode == ScrollModel.MODE_VERSE ? "Verse scroll" : "Line scroll";
        showToast(label);
    }

    function onToastExpired() as Void {
        toast = null;
        _toastTimer = null;
        WatchUi.requestUpdate();
    }

    function clearToastTimer() as Void {
        if (_toastTimer != null) {
            _toastTimer.stop();
            _toastTimer = null;
        }
    }

    function bookmarkFocusedVerse() as Void {
        var f = AppState.scroll.focusVerse();
        var result = Bookmarks.toggle(f[:book] as Lang.Number, f[:chapter] as Lang.Number, f[:verse] as Lang.Number);
        if (result == :added) {
            showToast("Bookmarked");
        } else if (result == :removed) {
            showToast("Bookmark removed");
        } else {
            showToast("Bookmarks full");
        }
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 100)]);
        }
    }

    function openMenu() as Void {
        ReaderMenu2.open(me);
    }

    function onEnterSleep() as Void {
        toast = null;
        clearToastTimer();
    }

    function onExitSleep() as Void {
    }

    static function openFor(book as Lang.Number, chapter as Lang.Number) as Void {
        AppState.selectedBook = book;
        AppState.selectedChapter = chapter;
        var view = new ReaderView();
        WatchUi.pushView(view, new ReaderDelegate(view), WatchUi.SLIDE_LEFT);
    }
}

class ReaderDelegate extends WatchUi.BehaviorDelegate {
    var _view as ReaderView;

    function initialize(view as ReaderView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Lang.Boolean {
        if (TouchGuard.consumePage()) {
            return true;
        }
        AppState.scroll.next();
        syncCurrentFromFocus();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        if (TouchGuard.consumePage()) {
            return true;
        }
        AppState.scroll.prev();
        syncCurrentFromFocus();
        WatchUi.requestUpdate();
        return true;
    }

    function syncCurrentFromFocus() as Void {
        var f = AppState.scroll.focusVerse();
        AppState.selectedBook = f[:book] as Lang.Number;
        AppState.selectedChapter = f[:chapter] as Lang.Number;
    }

    function onSelect() as Lang.Boolean {
        if (TouchGuard.consumeSelect()) {
            return true;
        }
        // POKE: tap opens Menu2; try tap-to-advance-verse as alternate.
        _view.openMenu();
        return true;
    }

    function onHold(evt) as Lang.Boolean {
        TouchGuard.markSelect();
        _view.bookmarkFocusedVerse();
        return true;
    }

    function onTap(evt) as Lang.Boolean {
        TouchGuard.markSelect();
        _view.openMenu();
        return true;
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            TouchGuard.markPage();
            AppState.scroll.next();
            syncCurrentFromFocus();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            TouchGuard.markPage();
            AppState.scroll.prev();
            syncCurrentFromFocus();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            // POKE: swipe-right = back
            TouchGuard.markBack();
            syncCurrentFromFocus();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onMenu() as Lang.Boolean {
        _view.openMenu();
        return true;
    }

    function onBack() as Lang.Boolean {
        if (TouchGuard.consumeBack()) {
            return true;
        }
        syncCurrentFromFocus();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
