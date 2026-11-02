using Toybox.Attention;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class ReaderView extends WatchUi.View {
    var toast as Lang.String or Null = null;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        // Reload mode from Storage
        AppState.scroll.mode = AppState.scroll.loadMode();
    }

    //! Build flattened lines for current book/chapter with optional next chapter continuation.
    function rebuildLines() as Void {
        var book = AppState.selectedBook;
        var chapter = AppState.selectedChapter;
        var lines = [] as Lang.Array;
        appendChapterLines(lines, book, chapter, false);

        // Prefetch next for continuation — POKE: trigger only near end (last N verses).
        var nxt = ChapterNav.nextChapter(book, chapter);
        if (nxt != null && ContentLoader.hasChapter(nxt.book, nxt.chapter)) {
            var divText = Books.name(nxt.book) + " " + nxt.chapter;
            lines.add(new ScrollModel.Line(ScrollModel.KIND_DIVIDER, nxt.book, nxt.chapter, 0, divText, false));
            appendChapterLines(lines, nxt.book, nxt.chapter, true);
        } else if (nxt == null && ChapterNav.isBibleEnd(book, chapter)) {
            lines.add(new ScrollModel.Line(ScrollModel.KIND_END, book, chapter, 0, "— End —", false));
        }

        // Optional previous chapter for backward cross — POKE: lazy-load when near start.
        AppState.scroll.lines = lines;
        AppState.scroll.scrollOffset = 0;
        AppState.scroll.clampOffset();
    }

    function appendChapterLines(lines as Lang.Array, book as Lang.Number, chapter as Lang.Number, _isContinuation as Lang.Boolean) as Void {
        var data = ContentLoader.loadChapter(book, chapter);
        if (data == null) {
            return;
        }
        var verses = data[:verses];
        if (verses == null) {
            return;
        }
        // POKE: maxChars from dc width / font metrics, not a constant.
        var maxChars = 22;
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
            var wrapped = ContentLoader.wrapVerse(n as Lang.Number, t as Lang.String, maxChars);
            var j;
            for (j = 0; j < wrapped.size(); j++) {
                var w = wrapped[j];
                lines.add(new ScrollModel.Line(
                    ScrollModel.KIND_VERSE,
                    book,
                    chapter,
                    w[:verse] as Lang.Number,
                    w[:text] as Lang.String,
                    w[:isStart] as Lang.Boolean
                ));
            }
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var inset = (w < h ? w : h) / 10;
        var focus = AppState.scroll.focusVerse();
        var title = Books.shortName(focus[:book] as Lang.Number) + " " + focus[:chapter] + ":" + focus[:verse];
        var chip = AppState.scroll.modeLabel();
        dc.drawText(inset, inset, Graphics.FONT_TINY, title, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(w - inset, inset, Graphics.FONT_TINY, chip, Graphics.TEXT_JUSTIFY_RIGHT);
        var y = inset + dc.getFontHeight(Graphics.FONT_TINY) + 4;
        dc.drawLine(inset, y, w - inset, y);
        y += 4;

        var lineH = dc.getFontHeight(Graphics.FONT_XTINY) + 2;
        AppState.scroll.visibleCount = (h - y - inset) / lineH;
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
            if (ln.kind == ScrollModel.KIND_DIVIDER) {
                // Compact continuation header — not a modal.
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_WHITE);
                dc.drawText(w / 2, y, Graphics.FONT_TINY, ln.text, Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
            } else if (ln.kind == ScrollModel.KIND_END) {
                dc.drawText(w / 2, y, Graphics.FONT_TINY, ln.text, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawText(inset, y, Graphics.FONT_XTINY, ln.text, Graphics.TEXT_JUSTIFY_LEFT);
            }
            y += lineH;
        }

        if (toast != null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.fillRectangle(inset, h / 2 - 10, w - 2 * inset, 20);
            dc.drawText(w / 2, h / 2 - 8, Graphics.FONT_TINY, toast, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        }
    }

    function onEnterSleep() as Void {
        // POKE: strip toast / reduce chrome on AMOLED to limit burn-in.
    }

    function onExitSleep() as Void {
    }

    static function openFor(book as Lang.Number, chapter as Lang.Number) as Void {
        AppState.selectedBook = book;
        AppState.selectedChapter = chapter;
        var view = new ReaderView();
        view.rebuildLines();
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
        // Short Select → reader menu (scroll mode toggle lives here — SPEC §9).
        WatchUi.pushView(new ReaderMenuView(), new ReaderMenuDelegate(_view), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onHold(evt) as Lang.Boolean {
        // POKE: also wire Select-key hold timing for button-only devices without touch onHold.
        var f = AppState.scroll.focusVerse();
        var result = Bookmarks.toggle(f[:book] as Lang.Number, f[:chapter] as Lang.Number, f[:verse] as Lang.Number);
        if (result == :added) {
            _view.toast = "Bookmarked";
        } else if (result == :removed) {
            _view.toast = "Removed";
        } else {
            _view.toast = "Bookmarks full";
        }
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 100)]);
        }
        WatchUi.requestUpdate();
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
