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

    //! Build flattened lines with chord-aware pixel wrap + divider breathing room.
    function rebuildLines(dc as Graphics.Dc) as Void {
        var book = AppState.selectedBook;
        var chapter = AppState.selectedChapter;
        var w = dc.getWidth();
        var h = dc.getHeight();
        var headerFont = Graphics.FONT_TINY;
        var headerH = dc.getFontHeight(headerFont) + 8;
        var lineH = dc.getFontHeight(_bodyFont) + 2;
        var contentTop = RoundLayout.edgeMargin(w, h) + headerH;
        var contentBottom = h - RoundLayout.edgeMargin(w, h);
        // Stable wrap width = minimum chord in the content band (scroll-stable line index).
        // POKE: screen-y variable reflow for denser mid-circle lines (needs pixel scroll model).
        var wrapW = RoundLayout.minChordInBand(contentTop + lineH / 2, contentBottom - lineH / 2, w, h);

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
        // POKE: DIVIDER_PAD_LINES — try 2 on large AMOLED if still cramped.
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
        // Full book name — never "Malac". Shrink font inside chord if needed.
        var title = Books.name(focus[:book] as Lang.Number) + " " + focus[:chapter] + ":" + focus[:verse];
        var chip = AppState.scroll.modeLabel();
        var headerFont = Graphics.FONT_TINY;
        var headerY = RoundLayout.edgeMargin(w, h);
        var headerMid = headerY + dc.getFontHeight(headerFont) / 2;
        var headerChord = RoundLayout.chordWidth(headerMid, w, h);
        var headerLeft = RoundLayout.chordLeft(headerMid, w, h);

        RoundLayout.drawCenteredInChord(dc, headerY, title, headerFont);
        // Mode chip inside right side of header chord (not past the circle).
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(headerLeft + headerChord - 2, headerY, headerFont, chip, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);

        var y = headerY + dc.getFontHeight(headerFont) + 4;
        var ruleLeft = RoundLayout.chordLeft(y, w, h);
        var ruleW = RoundLayout.chordWidth(y, w, h);
        dc.drawLine(ruleLeft, y, ruleLeft + ruleW, y);
        y += 4;

        var lineH = dc.getFontHeight(_bodyFont) + 2;
        var bottom = h - RoundLayout.edgeMargin(w, h);
        AppState.scroll.visibleCount = (bottom - y) / lineH;
        if (AppState.scroll.visibleCount < 1) {
            AppState.scroll.visibleCount = 1;
        }

        var lines = AppState.scroll.lines;
        var i;
        for (i = 0; i < AppState.scroll.visibleCount; i++) {
            var idx = AppState.scroll.scrollOffset + i;
            if (idx >= lines.size()) {
                break;
            }
            var ln = lines[idx] as ScrollModel.Line;
            var midY = y + lineH / 2;
            var left = RoundLayout.chordLeft(midY, w, h);
            var cw = RoundLayout.chordWidth(midY, w, h);

            if (ln.kind == ScrollModel.KIND_SPACER) {
                y += lineH;
                continue;
            }
            if (ln.kind == ScrollModel.KIND_DIVIDER) {
                // Distinct continuation header: thin rules + centered label, padded by KIND_SPACER.
                var ruleY1 = y + 2;
                var ruleY2 = y + lineH - 3;
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(left + 4, ruleY1, left + cw - 4, ruleY1);
                dc.drawLine(left + 4, ruleY2, left + cw - 4, ruleY2);
                dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y + 3, Graphics.FONT_TINY, ln.text, Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
            } else if (ln.kind == ScrollModel.KIND_END) {
                RoundLayout.drawCenteredInChord(dc, y, ln.text, Graphics.FONT_TINY);
            } else {
                dc.setClip(left, y, cw, lineH);
                dc.drawText(left, y, _bodyFont, ln.text, Graphics.TEXT_JUSTIFY_LEFT);
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
        // POKE: RoundLayout.TOAST_MS — try 800..1500 after vibe tuning.
        _toastTimer.start(method(:onToastExpired), RoundLayout.TOAST_MS, false);
        WatchUi.requestUpdate();
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

    function onEnterSleep() as Void {
        // POKE: strip toast / reduce chrome on AMOLED to limit burn-in.
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
        AppState.scroll.next();
        syncCurrentFromFocus();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
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
        WatchUi.pushView(new ReaderMenuView(), new ReaderMenuDelegate(_view), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onHold(evt) as Lang.Boolean {
        // POKE: also wire Select-key hold timing for button-only devices without touch onHold.
        var f = AppState.scroll.focusVerse();
        var result = Bookmarks.toggle(f[:book] as Lang.Number, f[:chapter] as Lang.Number, f[:verse] as Lang.Number);
        if (result == :added) {
            _view.showToast("Bookmarked");
        } else if (result == :removed) {
            _view.showToast("Bookmark removed");
        } else {
            _view.showToast("Bookmarks full");
        }
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 100)]);
        }
        return true;
    }

    function onMenu() as Lang.Boolean {
        WatchUi.pushView(new ReaderMenuView(), new ReaderMenuDelegate(_view), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onBack() as Lang.Boolean {
        syncCurrentFromFocus();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
