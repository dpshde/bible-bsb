using Toybox.Attention;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Timer;
using Toybox.WatchUi;

//! Center-band lens reader. Eager-wraps the opened chapter only; defers the
//! continuation chapter across a Timer tick so open stays under the 240k watchdog.
//! Every verse starts on a new line (no run-on paragraph); gold inline numbers.
class ReaderView extends WatchUi.View {
    var toast as Lang.String or Null = null;
    var _toastTimer as Timer.Timer or Null = null;
    var _deferTimer as Timer.Timer or Null = null;
    var _laidOut as Lang.Boolean = false;
    var _bodyFont as Graphics.FontDefinition = Graphics.FONT_XTINY;
    var _numFont as Graphics.FontDefinition = Graphics.FONT_XTINY;
    var _colLeft as Lang.Number = 0;
    var _colWidth as Lang.Number = 0;
    var _bandTop as Lang.Number = 0;
    var _bandBottom as Lang.Number = 0;
    var _metaBottom as Lang.Number = 0;
    var _previewTop as Lang.Number = 0;
    var _wrapBook as Lang.Number = 0;
    var _wrapChapter as Lang.Number = 0;
    var _continuationPending as Lang.Boolean = false;
    var _verseCount as Lang.Number = 0;

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
        clearDeferTimer();
    }

    function applyLens(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var lens = RoundLayout.lensBand(w, h);
        _metaBottom = lens[:metaBottom] as Lang.Number;
        _bandTop = lens[:bandTop] as Lang.Number;
        _bandBottom = lens[:bandBottom] as Lang.Number;
        _previewTop = lens[:previewTop] as Lang.Number;
        _colLeft = lens[:left] as Lang.Number;
        _colWidth = lens[:width] as Lang.Number;
    }

    function rebuildLines(dc as Graphics.Dc) as Void {
        applyLens(dc);
        _wrapBook = AppState.selectedBook;
        _wrapChapter = AppState.selectedChapter;
        _bodyFont = Graphics.FONT_XTINY;
        _numFont = Graphics.FONT_XTINY;

        var lines = [] as Lang.Array;
        appendChapterLines(dc, lines, _wrapBook, _wrapChapter, _colWidth);
        _verseCount = ContentLoader.verseCount(_wrapBook, _wrapChapter);

        AppState.scroll.lines = lines;
        // POKE: dynamic font — if focused verse fits the band one size larger in Verse mode, grow.
        maybeGrowFontForFocus(dc, AppState.scroll.lines);
        AppState.scroll.scrollOffset = 0;
        var lineH = dc.getFontHeight(_bodyFont) + 2;
        var bandH = _bandBottom - _bandTop;
        AppState.scroll.visibleCount = bandH / lineH;
        if (AppState.scroll.visibleCount < 1) {
            AppState.scroll.visibleCount = 1;
        }
        if (AppState.scroll.visibleCount > 5) {
            AppState.scroll.visibleCount = 5; // lens: max ~4–5 lines
        }
        AppState.scroll.clampOffset();

        // Defer continuation chapter wrap to next tick (watchdog).
        _continuationPending = false;
        var nxt = ChapterNav.nextChapter(_wrapBook, _wrapChapter);
        if (nxt != null && ContentLoader.hasChapter(nxt.book, nxt.chapter)) {
            _continuationPending = true;
            clearDeferTimer();
            _deferTimer = new Timer.Timer();
            _deferTimer.start(method(:onDeferContinuation), 50, false);
        } else if (nxt == null && ChapterNav.isBibleEnd(_wrapBook, _wrapChapter)) {
            AppState.scroll.lines.add(new ScrollModel.Line(
                ScrollModel.KIND_END, _wrapBook, _wrapChapter, 0, "— End —", false));
        }
    }

    //! Second-phase wrap of next chapter — keeps open path under 240k instructions.
    function onDeferContinuation() as Void {
        _deferTimer = null;
        if (!_continuationPending) {
            return;
        }
        _continuationPending = false;
        var nxt = ChapterNav.nextChapter(_wrapBook, _wrapChapter);
        if (nxt == null || !ContentLoader.hasChapter(nxt.book, nxt.chapter)) {
            return;
        }
        // Marker line: ensureContinuationWrapped expands divider + next chapter on next paint.
        AppState.scroll.lines.add(new ScrollModel.Line(
            ScrollModel.KIND_SPACER, nxt.book, nxt.chapter, 0, "__WRAP_NEXT__", false));
        WatchUi.requestUpdate();
    }

    function ensureContinuationWrapped(dc as Graphics.Dc) as Void {
        var lines = AppState.scroll.lines;
        if (lines.size() == 0) {
            return;
        }
        var last = lines[lines.size() - 1] as ScrollModel.Line;
        if (last.kind != ScrollModel.KIND_SPACER || !last.text.equals("__WRAP_NEXT__")) {
            return;
        }
        lines.remove(last);
        var nxtBook = last.book;
        var nxtChapter = last.chapter;
        appendDivider(lines, nxtBook, nxtChapter);
        appendChapterLines(dc, lines, nxtBook, nxtChapter, _colWidth);
        AppState.scroll.clampOffset();
    }

    function appendDivider(lines as Lang.Array, book as Lang.Number, chapter as Lang.Number) as Void {
        var divText = Books.name(book) + " " + chapter;
        var pad = RoundLayout.DIVIDER_PAD_LINES;
        var i;
        for (i = 0; i < pad; i++) {
            lines.add(new ScrollModel.Line(ScrollModel.KIND_SPACER, book, chapter, 0, "", false));
        }
        lines.add(new ScrollModel.Line(ScrollModel.KIND_DIVIDER, book, chapter, 0, divText, false));
        for (i = 0; i < pad; i++) {
            lines.add(new ScrollModel.Line(ScrollModel.KIND_SPACER, book, chapter, 0, "", false));
        }
    }

    function maybeGrowFontForFocus(dc as Graphics.Dc, lines as Lang.Array) as Void {
        // POKE: on threshold — grow only in Verse mode when the focused verse fits.
        if (AppState.scroll.mode != ScrollModel.MODE_VERSE) {
            return;
        }
        var larger = RoundLayout.growFont(_bodyFont);
        if (larger == _bodyFont) {
            return;
        }
        // Count lines belonging to first verse at current wrap; re-wrap that verse at larger.
        if (lines.size() == 0) {
            return;
        }
        var first = lines[0] as ScrollModel.Line;
        if (first.kind != ScrollModel.KIND_VERSE) {
            return;
        }
        var data = ContentLoader.loadChapter(first.book, first.chapter);
        if (data == null) {
            return;
        }
        var verses = data[:verses] as Lang.Array;
        var t as Lang.String or Null = null;
        var i;
        for (i = 0; i < verses.size(); i++) {
            var v = verses[i];
            var n = v["n"];
            if (n == null) {
                n = v[:n];
            }
            if (n == first.verse) {
                t = v["t"];
                if (t == null) {
                    t = v[:t];
                }
                break;
            }
        }
        if (t == null) {
            return;
        }
        var wrapped = ContentLoader.wrapVerseToWidth(dc, larger, first.verse, t as Lang.String, _colWidth);
        var lineH = dc.getFontHeight(larger) + 2;
        var bandH = _bandBottom - _bandTop;
        if (wrapped.size() * lineH <= bandH) {
            _bodyFont = larger;
            // Re-wrap whole chapter at larger size; caller uses AppState.scroll.lines after.
            var rebuilt = [] as Lang.Array;
            appendChapterLines(dc, rebuilt, _wrapBook, _wrapChapter, _colWidth);
            AppState.scroll.lines = rebuilt;
        }
    }

    function appendChapterLines(dc as Graphics.Dc, lines as Lang.Array, book as Lang.Number,
                                chapter as Lang.Number, wrapW as Lang.Number) as Void {
        ContentLoader.clearWordCache();
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
                var isStart = row[:isStart] as Lang.Boolean;
                // Text without leading "N "; gold prefix drawn at paint time when isStart.
                lines.add(new ScrollModel.Line(
                    ScrollModel.KIND_VERSE,
                    book,
                    chapter,
                    row[:verse] as Lang.Number,
                    row[:text] as Lang.String,
                    isStart
                ));
            }
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (!_laidOut) {
            rebuildLines(dc);
            _laidOut = true;
        }
        ensureContinuationWrapped(dc);
        applyLens(dc);

        Palette.applyBackground(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();

        var focus = resolveFocus();
        var book = focus[:book] as Lang.Number;
        var chapter = focus[:chapter] as Lang.Number;
        var verse = focus[:verse] as Lang.Number;

        // Top arc 0–18%: centered metadata only. Nothing else.
        var meta = Books.refLabel(book, chapter, verse);
        var full = Books.name(book) + " " + chapter + ":" + verse;
        var metaFont = Graphics.FONT_XTINY;
        var metaY = (_metaBottom - dc.getFontHeight(metaFont)) / 2;
        if (metaY < 2) {
            metaY = 2;
        }
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        // Prefer full name when it fits the top chord; else OSIS.
        var topChord = RoundLayout.rawChordWidth(metaY + dc.getFontHeight(metaFont) / 2, w, h);
        var label = dc.getTextWidthInPixels(full, metaFont) <= topChord - 8 ? full : meta;
        dc.setClip(0, 0, w, _metaBottom);
        dc.drawText(w / 2, metaY, metaFont, label, Graphics.TEXT_JUSTIFY_CENTER);
        dc.clearClip();

        // Progress arc (replaces scrollbar).
        var progress = 0.0;
        if (_verseCount > 0) {
            progress = verse.toFloat() / _verseCount.toFloat();
        }
        RoundLayout.drawProgressArc(dc, progress, bookmarkFracsFor(book, chapter));

        // Center band: clip everything to the band.
        var lineH = dc.getFontHeight(_bodyFont) + 2;
        var bandH = _bandBottom - _bandTop;
        AppState.scroll.visibleCount = bandH / lineH;
        if (AppState.scroll.visibleCount < 1) {
            AppState.scroll.visibleCount = 1;
        }
        if (AppState.scroll.visibleCount > 5) {
            AppState.scroll.visibleCount = 5;
        }

        dc.setClip(_colLeft, _bandTop, _colWidth, bandH);
        var y = _bandTop;
        var lines = AppState.scroll.lines;
        var gapPx = (lineH * RoundLayout.VERSE_GAP_FRAC).toNumber();
        if (gapPx < 2) {
            gapPx = 2;
        }
        var prevWasVerse = false;
        var prevVerse = -1;
        var i;
        // Draw until band bottom — visibleCount is a soft budget; gaps eat space.
        var drawn = 0;
        var maxDraw = AppState.scroll.visibleCount + 2;
        for (i = 0; i < maxDraw; i++) {
            var idx = AppState.scroll.scrollOffset + i;
            if (idx >= lines.size()) {
                break;
            }
            if (y + lineH > _bandBottom) {
                break;
            }
            var ln = lines[idx] as ScrollModel.Line;
            if (ln.kind == ScrollModel.KIND_SPACER) {
                y += lineH;
                prevWasVerse = false;
                continue;
            }
            // Inter-verse gap: every verse starts on a new line with air above (not run-on).
            if (ln.kind == ScrollModel.KIND_VERSE && ln.isVerseStart && prevWasVerse
                && (ln.verse != prevVerse || drawn > 0)) {
                y += gapPx;
                if (y + lineH > _bandBottom) {
                    break;
                }
            }
            if (ln.kind == ScrollModel.KIND_DIVIDER) {
                // ~1 line pad above/below is carried by KIND_SPACER rows in the buffer.
                drawDivider(dc, y, lineH, ln.text);
                prevWasVerse = false;
            } else if (ln.kind == ScrollModel.KIND_END) {
                dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y, Graphics.FONT_TINY, ln.text, Graphics.TEXT_JUSTIFY_CENTER);
                prevWasVerse = false;
            } else {
                drawVerseLine(dc, y, lineH, ln, book, chapter, verse);
                prevWasVerse = true;
                prevVerse = ln.verse;
            }
            y += lineH;
            drawn++;
        }
        dc.clearClip();

        // Bottom arc 82–100%: dimmed counter or next-verse preview. Nothing else.
        dc.setClip(0, _previewTop, w, h - _previewTop);
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        var previewFont = Graphics.FONT_XTINY;
        var previewY = _previewTop + (h - _previewTop - dc.getFontHeight(previewFont)) / 2;
        var preview;
        if (RoundLayout.LENS_PREVIEW_VERSE_COUNTER) {
            preview = verse + " / " + (_verseCount > 0 ? _verseCount : "?");
        } else {
            preview = nextVersePreview(book, chapter, verse);
        }
        dc.drawText(w / 2, previewY, previewFont, preview, Graphics.TEXT_JUSTIFY_CENTER);
        dc.clearClip();

        if (toast != null) {
            RoundLayout.drawToastPill(dc, toast);
        }
    }

    function drawVerseLine(dc as Graphics.Dc, y as Lang.Number, lineH as Lang.Number,
                           ln as ScrollModel.Line, focusBook as Lang.Number,
                           focusChapter as Lang.Number, focusVerse as Lang.Number) as Void {
        var x = _colLeft;
        var isFocus = ln.book == focusBook && ln.chapter == focusChapter && ln.verse == focusVerse;
        // Dim non-focused verses in verse-snap mode so the focused verse reads primary.
        var bodyColor = Palette.TEXT;
        if (AppState.scroll.mode == ScrollModel.MODE_VERSE && !isFocus) {
            bodyColor = Palette.DIM_VERSE; // POKE: Palette.DIM_VERSE
        }
        if (ln.isVerseStart) {
            // Gold inline verse number at line start — slightly smaller than body.
            var num = ln.verse.toString();
            dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
            var numY = y - 1;
            if (numY < _bandTop) {
                numY = y;
            }
            dc.drawText(x, numY, _numFont, num, Graphics.TEXT_JUSTIFY_LEFT);
            x += dc.getTextWidthInPixels(num, _numFont) + 4;
        }
        dc.setColor(bodyColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, _bodyFont, ln.text, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawDivider(dc as Graphics.Dc, y as Lang.Number, lineH as Lang.Number,
                         label as Lang.String) as Void {
        // Spec: ~1 line pad via spacers; thin 1px rules (DIVIDER_RULE) with 6–8px gap
        // from gold centered label; fully inside band chord (clip already set).
        var padX = 8;
        var gap = 8; // POKE: divider label↔rule gap (6–8px)
        var font = Graphics.FONT_TINY;
        var tw = dc.getTextWidthInPixels(label, font);
        var midX = _colLeft + _colWidth / 2;
        var ruleY = y + lineH / 2;
        var labelLeft = midX - tw / 2 - gap;
        var labelRight = midX + tw / 2 + gap;
        dc.setColor(Palette.DIVIDER_RULE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        if (labelLeft - (_colLeft + padX) > 4) {
            dc.drawLine(_colLeft + padX, ruleY, labelLeft, ruleY);
        }
        if ((_colLeft + _colWidth - padX) - labelRight > 4) {
            dc.drawLine(labelRight, ruleY, _colLeft + _colWidth - padX, ruleY);
        }
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(midX, y + (lineH - dc.getFontHeight(font)) / 2, font, label,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function resolveFocus() as Lang.Dictionary {
        var f = AppState.scroll.focusVerse();
        if ((f[:book] as Lang.Number) < 0) {
            return {
                :book => AppState.selectedBook,
                :chapter => AppState.selectedChapter,
                :verse => 1
            };
        }
        return f;
    }

    function nextVersePreview(book as Lang.Number, chapter as Lang.Number,
                              verse as Lang.Number) as Lang.String {
        var t = ContentLoader.verseText(book, chapter, verse + 1);
        if (t == null) {
            var nxt = ChapterNav.nextChapter(book, chapter);
            if (nxt != null) {
                t = ContentLoader.verseText(nxt.book, nxt.chapter, 1);
            }
        }
        if (t == null) {
            return "";
        }
        if (t.length() > 28) {
            return t.substring(0, 28) + "…";
        }
        return t;
    }

    function bookmarkFracsFor(book as Lang.Number, chapter as Lang.Number) as Lang.Array {
        var out = [] as Lang.Array;
        if (_verseCount <= 0) {
            return out;
        }
        var list = Bookmarks.load();
        var i;
        for (i = 0; i < list.size(); i++) {
            var id = list[i] as Lang.Number;
            if (Bookmarks.unpackBook(id) == book && Bookmarks.unpackChapter(id) == chapter) {
                var v = Bookmarks.unpackVerse(id);
                if (v > 0) {
                    out.add(v.toFloat() / _verseCount.toFloat());
                }
            }
        }
        return out;
    }

    function showToast(message as Lang.String) as Void {
        toast = message;
        clearToastTimer();
        _toastTimer = new Timer.Timer();
        // POKE: RoundLayout.TOAST_MS (~1s visible)
        _toastTimer.start(method(:onToastExpired), RoundLayout.TOAST_MS, false);
        WatchUi.requestUpdate();
    }

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

    function clearDeferTimer() as Void {
        if (_deferTimer != null) {
            _deferTimer.stop();
            _deferTimer = null;
        }
    }

    function bookmarkFocusedVerse() as Void {
        var f = resolveFocus();
        var result = Bookmarks.toggle(f[:book] as Lang.Number, f[:chapter] as Lang.Number, f[:verse] as Lang.Number);
        if (result == :added) {
            showToast("Bookmarked");
        } else if (result == :removed) {
            showToast("Bookmark removed");
        } else {
            showToast("Bookmarks full");
        }
        WatchUi.requestUpdate();
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
        var f = _view.resolveFocus();
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
        // SPEC: return to grid for *current* (possibly continued) chapter.
        syncCurrentFromFocus();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
