using Toybox.Attention;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

//! Center-band lens reader. Eager-wraps the opened chapter only; defers the
//! continuation chapter across a Timer tick so open stays under the 240k watchdog.
//! Every verse starts on a new line (no run-on paragraph); gold inline numbers.
//! System fonts only (BMFont weighting reverted — see docs/font-budget.md).
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
    // Chunked wrap state (stock 240k watchdog: Psalm 119 = 176 verses tripped eager wrap).
    // POKE: WRAP_CHUNK_VERSES — verses wrapped per paint; rest continue on Timer ticks.
    const WRAP_CHUNK_VERSES = 20;
    // POKE: WRAP_FIRST_VERSES — first paint wraps only what fits on screen (instant open);
    // the rest of the chapter fills in on the following 50 ms ticks.
    const WRAP_FIRST_VERSES = 4;
    var _chunk as Lang.Number = 20;
    var _pendVerses as Lang.Array or Null = null;
    var _pendBook as Lang.Number = 0;
    var _pendChapter as Lang.Number = 0;
    var _pendIdx as Lang.Number = 0;
    var _pendPrimary as Lang.Boolean = false;
    var _needChunk as Lang.Boolean = false;
    var _pendingJump as Lang.Number = 0;
    var _verseCount as Lang.Number = 0;
    var shownAt as Lang.Number = 0; // InputGate: when this reader appeared

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        rebuildLines(dc);
        _laidOut = true;
    }

    function onShow() as Void {
        shownAt = System.getTimer();
        AppState.scroll.mode = AppState.scroll.loadMode();
        clearLineCache(); // theme may have toggled while the menu was up
        _headKey = null;
        // Resume a wrap that was paused while Menu2 / another view was on top.
        if (_laidOut && (_pendVerses != null || _continuationPending)) {
            scheduleChunk();
        }
    }

    function onHide() as Void {
        clearToastTimer();
        clearDeferTimer();
        if (_preTimer != null) {
            (_preTimer as Timer.Timer).stop();
        }
        _preIdx = [] as Lang.Array;
        LastReadApp.flush();
    }

    var _lens as Lang.Dictionary or Null = null; // PERF: computed once per screen size
    var _headKey as Lang.String or Null = null;  // PERF: header pyramid cache key (heading text)
    var _headRows as Lang.Array = ["", ""];
    var _headThree as Lang.Array or Null = null;
    var _fracKey as Lang.Number = -1;            // PERF: bookmark-tick cache key
    var _fracs as Lang.Array = [] as Lang.Array;
    var _numW as Lang.Dictionary = {};
    var _focKey as Lang.Number = -1;
    var _focSections as Lang.Array = [] as Lang.Array;
    var _focCount as Lang.Number = 0;
    var _refKey as Lang.Number = -1;             // PERF: bottom-ref string cache key
    var _ref as Lang.String = "";

    function applyLens(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (_lens == null) {
            _lens = RoundLayout.lensBand(w, h);
        }
        var lens = _lens as Lang.Dictionary;
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
        clearLineCache();
        AppState.sections = [];
        AppState.scroll.lines = lines;
        AppState.scroll.scrollOffset = 0;
        _continuationPending = false;
        _pendingJump = 0;
        ContentLoader.clearWordCache();
        startChapterWrap(_wrapBook, _wrapChapter, true);
        _chunk = LastReadApp.resumeVerse > 1 ? WRAP_CHUNK_VERSES : WRAP_FIRST_VERSES;
        wrapChunk(dc);
        // Resume last-read verse once (relaunch into the same chapter).
        if (LastReadApp.resumeVerse > 1) {
            var rv = LastReadApp.resumeVerse;
            LastReadApp.resumeVerse = 0;
            var lp = LastReadApp.pending;
            if (lp != null && lp[0] == _wrapBook && lp[1] == _wrapChapter) {
                jumpToVerse(rv);
            }
        } else {
            LastReadApp.resumeVerse = 0;
        }
        _verseCount = ContentLoader.verseCount(_wrapBook, _wrapChapter);
        _focKey = -1;

        // POKE: dynamic font — if focused verse fits the band one size larger in Verse mode, grow.
        // POKE: font-grow re-wraps the whole chapter a 2nd time on open -> trips the stock
        // 240k watchdog on Enduro 3 (John 3). Disabled until grow is lazy/per-verse.
        // maybeGrowFontForFocus(dc, AppState.scroll.lines);
        // (scrollOffset is reset BEFORE the wrap + resume jump above; resetting it here wiped
        // the last-read resume — edge pass B17.)
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

        if (_pendVerses != null) {
            scheduleChunk();
        } else {
            finishPrimary();
        }
    }

    //! Primary chapter fully wrapped: queue the continuation chapter (or the End line).
    function finishPrimary() as Void {
        var nxt = ChapterNav.nextChapter(_wrapBook, _wrapChapter);
        if (nxt != null && ContentLoader.hasChapter(nxt.book, nxt.chapter)) {
            _continuationPending = true;
            scheduleChunk();
        } else if (nxt == null && ChapterNav.isBibleEnd(_wrapBook, _wrapChapter)) {
            AppState.scroll.lines.add(new ScrollModel.Line(
                ScrollModel.KIND_END, _wrapBook, _wrapChapter, 0, "— End —", false));
        }
    }

    //! One reused Timer per reader (CIQ caps live timers: "Too Many Timers Error").
    function scheduleChunk() as Void {
        if (_deferTimer == null) {
            _deferTimer = new Timer.Timer();
        } else {
            _deferTimer.stop();
        }
        _deferTimer.start(method(:onDeferContinuation), 50, false);
    }

    //! Timer tick: wrapping needs a Dc, so ask for a paint; onUpdate wraps one chunk.
    function onDeferContinuation() as Void {
        _deferTimer = null;
        _needChunk = true;
        WatchUi.requestUpdate();
    }

    //! One bounded step per paint: next chunk of the pending chapter, or start the
    //! continuation chapter (divider + first chunk). Never wraps a whole chapter at once.
    function ensureContinuationWrapped(dc as Graphics.Dc) as Void {
        if (!_needChunk) {
            return;
        }
        _needChunk = false;
        if (_pendVerses == null && _continuationPending) {
            _continuationPending = false;
            var nxt = ChapterNav.nextChapter(_wrapBook, _wrapChapter);
            if (nxt == null || !ContentLoader.hasChapter(nxt.book, nxt.chapter)) {
                return;
            }
            appendDivider(AppState.scroll.lines, nxt.book, nxt.chapter);
            startChapterWrap(nxt.book, nxt.chapter, false);
        }
        if (_pendVerses == null) {
            return;
        }
        var wasPrimary = _pendPrimary;
        wrapChunk(dc);
        AppState.scroll.clampOffset();
        if (_pendVerses != null) {
            scheduleChunk();
        } else if (wasPrimary) {
            finishPrimary();
        }
    }

    function startChapterWrap(book as Lang.Number, chapter as Lang.Number, primary as Lang.Boolean) as Void {
        _pendVerses = null;
        var data = ContentLoader.loadChapter(book, chapter);
        if (data == null) {
            return;
        }
        if (primary) {
            AppState.sections = data[:sections] as Lang.Array;
        }
        var verses = data[:verses];
        if (verses == null) {
            return;
        }
        _pendVerses = verses as Lang.Array;
        _pendBook = book;
        _pendChapter = chapter;
        _pendIdx = 0;
        _pendPrimary = primary;
    }

    function wrapChunk(dc as Graphics.Dc) as Void {
        var verses = _pendVerses;
        if (verses == null) {
            return;
        }
        var to = _pendIdx + _chunk;
        _chunk = WRAP_CHUNK_VERSES;
        if (to > verses.size()) {
            to = verses.size();
        }
        appendVerseRange(dc, AppState.scroll.lines, _pendBook, _pendChapter, verses, _pendIdx, to, _colWidth);
        _pendIdx = to;
        if (_pendIdx >= verses.size()) {
            _pendVerses = null;
        }
        if (_pendingJump > 0 && _pendPrimary) {
            var j = _pendingJump;
            _pendingJump = 0;
            jumpToVerse(j);
        }
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
        var t = null;
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
        if (data == null || data[:verses] == null) {
            return;
        }
        var verses = data[:verses] as Lang.Array;
        appendVerseRange(dc, lines, book, chapter, verses, 0, verses.size(), wrapW);
    }

    function appendVerseRange(dc as Graphics.Dc, lines as Lang.Array, book as Lang.Number,
                              chapter as Lang.Number, verses as Lang.Array, from as Lang.Number,
                              to as Lang.Number, wrapW as Lang.Number) as Void {
        var i;
        for (i = from; i < to; i++) {
            var v = verses[i];
            var n = v["n"];
            var t = v["t"];
            if (n == null) {
                n = v[:n];
            }
            if (t == null) {
                t = v[:t];
            }
            var text = t as Lang.String;
            // POKE: WORDS_OF_JESUS — spike JSON has no \wj; hook skips tint until markup ships.
            if (ContentLoader.hasJesusMarkup(text)) {
                // Future: split runs and draw with Palette.JESUS.
            }
            text = ContentLoader.plainVerseText(text);
            var vchars = text.length();
            // POKE: ONE_VERSE_FONT — Dylan's locked rule: every verse uses the same face;
            // focus is dimming-only. (Short-verse TINY bump removed: it clipped e.g. John 4:43.)
            var pull = false;
            var face = _bodyFont;
            var wrapped = ContentLoader.wrapVerseToWidth(
                dc, face, n as Lang.Number, text, wrapW);
            var j;
            for (j = 0; j < wrapped.size(); j++) {
                var row = wrapped[j];
                var isStart = row[:isStart] as Lang.Boolean;
                var ln = new ScrollModel.Line(
                    ScrollModel.KIND_VERSE,
                    book,
                    chapter,
                    row[:verse] as Lang.Number,
                    row[:text] as Lang.String,
                    isStart
                );
                ln.pullQuote = pull;
                ln.verseChars = vchars;
                lines.add(ln);
            }
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var t0 = Perf.start();
        onUpdateImpl(dc);
        schedulePrerender();
        Perf.end("reader", t0);
    }

    function onUpdateImpl(dc as Graphics.Dc) as Void {
        Perf.segStart();
        if (!_laidOut) {
            rebuildLines(dc);
            _laidOut = true;
        }
        ensureContinuationWrapped(dc);
        applyLens(dc);

        Perf.seg("wrap");
        Palette.applyBackground(dc);
        Perf.seg("clear");
        var w = dc.getWidth();
        var h = dc.getHeight();

        var focus = resolveFocus();
        LastReadApp.note(focus[:book] as Lang.Number, focus[:chapter] as Lang.Number, focus[:verse] as Lang.Number);
        var book = focus[:book] as Lang.Number;
        var chapter = focus[:chapter] as Lang.Number;
        var verse = focus[:verse] as Lang.Number;

        // Top arc (Dylan, final): two rows for the section heading only, small caps,
        // row 1 = narrow chord, row 2 = wider chord below. No heading -> "Book N".
        // OSIS ref lives in the bottom arc; progress stays on the bezel arc.
        var headFont = Graphics.FONT_XTINY;
        var headH = dc.getFontHeight(headFont);
        // Header + ring follow the FOCUSED chapter (continuation chapter after a divider),
        // from the 2-slot chapter cache (no reload).
        if (_focKey != book * 1000 + chapter) {
            _focKey = book * 1000 + chapter;
            if (book == _wrapBook && chapter == _wrapChapter) {
                _focSections = AppState.sections;
                _focCount = _verseCount;
            } else {
                var fd = ContentLoader.loadChapter(book, chapter);
                _focSections = fd != null ? fd[:sections] as Lang.Array : [] as Lang.Array;
                _focCount = fd != null ? ContentLoader.lastVerseOf(fd) : 0;
            }
        }
        var sticky = ContentLoader.stickySectionTitle(_focSections, verse);
        var headText = (sticky != null && (sticky as Lang.String).length() > 0)
            ? sticky as Lang.String : Books.name(book) + " " + chapter;
        // POKE: HEAD_ROW1_Y — row 1 sits below the bezel progress ring (radius-2, PEN px)
        // by >= 10% of the radius + 6px (Dylan), so it never kisses the ring.
        var radius = (w < h ? w : h) / 2;
        var row1Y = 2 + RoundLayout.PROGRESS_ARC_PEN + (radius * 0.10).toNumber() + 6;
        // POKE: HEAD_ROW2_Y — top of heading row 2 (wider), directly under row 1.
        var row2Y = row1Y + headH - 3;
        // POKE: HEAD_CHORD_MARGIN — px trimmed per side from each row's chord (row 1 is narrower
        // because it is measured at its own, higher y; use the row's TOP edge, its narrowest point).
        var headMargin = 10;
        var c1 = RoundLayout.rawChordWidth(row1Y, w, h) - 2 * headMargin;
        var c2 = RoundLayout.rawChordWidth(row2Y, w, h) - 2 * headMargin;
        var row3Y = row2Y + headH - 3;
        var rows = null;
        var three = null;
        if (_headKey != null && (_headKey as Lang.String).equals(headText)) {
            // PERF: same heading as last frame -> reuse the measured pyramid (no text measure).
            rows = _headRows;
            three = _headThree;
        } else {
        rows = wrapTwo(dc, headText.toUpper(), headFont, c1, c2);
        if (rows == null) {
            rows = wrapTwo(dc, headText, headFont, c1, c2); // mixed case is narrower
        }
        // POKE: HEAD_ROW3 — long headings (Ps 119 "Your Word Is a Lamp to My Feet - ALEPH")
        // take a third, wider row before any ellipsis (no abbreviations, Dylan).
        var c3 = RoundLayout.rawChordWidth(row3Y, w, h) - 2 * headMargin;
        if (rows == null) {
            three = wrapThree(dc, headText.toUpper(), headFont, c1, c2, c3);
            if (three == null) {
                three = wrapThree(dc, headText, headFont, c1, c2, c3);
            }
            if (three != null) {
                rows = [three[0], three[1]];
            }
        }
        if (rows == null) {
            // last resort: both rows used (pyramid), only row 2 ellipsized.
            rows = RoundLayout.pyramidSplitEllipsize(dc, headText.toUpper(), headFont, c1, c2);
        }
        _headKey = headText;
        _headRows = rows as Lang.Array;
        _headThree = three;
        }
        // POKE: HEAD_COLOR — heading gold (upstream) vs MUTED, since the bottom ref is gold too.
        dc.setColor(tc(Palette.GOLD), Graphics.COLOR_TRANSPARENT);
        var headBottom = row1Y;
        if ((rows[0] as Lang.String).length() > 0) {
            dc.drawText(w / 2, row1Y, headFont, rows[0] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
            headBottom = row1Y + headH;
        }
        if ((rows[1] as Lang.String).length() > 0) {
            dc.drawText(w / 2, row2Y, headFont, rows[1] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
            headBottom = row2Y + headH;
        }
        if (three != null && (three[2] as Lang.String).length() > 0) {
            dc.drawText(w / 2, row3Y, headFont, three[2] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
            headBottom = row3Y + headH;
        }
        // POKE: HEAD_BAND_GAP — px between heading block and reading band.
        if (_bandTop < headBottom + 3) {
            _bandTop = headBottom + 3;
        }

        Perf.seg("head");
        // Progress arc (replaces scrollbar).
        var progress = 0.0;
        if (_focCount > 0) {
            progress = verse.toFloat() / _focCount.toFloat();
        }
        if (toast == null) {
            var fk = (book * 1000 + chapter) * 1000 + (Bookmarks.version % 1000);
            if (fk != _fracKey) {
                _fracs = bookmarkFracsFor(book, chapter);
                _fracKey = fk;
            }
            RoundLayout.drawProgressArc(dc, progress, _fracs);
        }

        Perf.seg("arc");
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

        if (AppState.scroll.lines.size() == 0) {
            // Chapter not in the bundled stub set (e.g. Malachi 1) — say so instead of a blank band.
            dc.setColor(tc(Palette.MUTED), Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2 - dc.getFontHeight(Graphics.FONT_XTINY), Graphics.FONT_XTINY,
                "Not bundled yet", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        // PERF: no setClip — lines are wrapped to _colWidth and the loop stops at _bandBottom,
        // so nothing can spill; clipped text rendering was the costly path.
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
                dc.setColor(tc(Palette.MUTED), Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y, Graphics.FONT_TINY, ln.text, Graphics.TEXT_JUSTIFY_CENTER);
                prevWasVerse = false;
            } else {
                drawVerseLineCached(dc, y, lineH, idx, ln, book, chapter, verse);
                prevWasVerse = true;
                prevVerse = ln.verse;
            }
            y += lineH;
            drawn++;
        }
        dc.clearClip();
        Perf.seg("lines");

        // Bottom arc 82–100%: dimmed counter or next-verse preview. Nothing else.
        dc.setClip(0, _previewTop, w, h - _previewTop);
        // Bottom arc (Dylan): short OSIS ref, small gold, replaces the "X / Y" counter.
        dc.setColor(tc(Palette.GOLD), Graphics.COLOR_TRANSPARENT);
        var previewFont = Graphics.FONT_XTINY;
        // POKE: REF_BOTTOM_Y — ref row is centered in the bottom arc (previewTop..h).
        var previewY = _previewTop + (h - _previewTop - dc.getFontHeight(previewFont)) / 2;
        var rk = (book * 1000 + chapter) * 1000 + verse;
        if (rk != _refKey) {
            _ref = Books.refLabel(book, chapter, verse);
            _refKey = rk;
        }
        var preview = _ref;
        dc.drawText(w / 2, previewY, previewFont, preview, Graphics.TEXT_JUSTIFY_CENTER);
        dc.clearClip();

        if (toast != null) {
            RoundLayout.drawToastPill(dc, toast);
        }
        Perf.seg("ref");
        Perf.segEnd();
    }

    // PERF: LINE BITMAP CACHE. Enduro 3 system fonts are TTF (rasterized per glyph each
    // drawText). Each wrapped line is rendered once per (line, focused?) into a
    // BufferedBitmap; frames blit. A scroll step rasterizes only lines that are new or whose
    // focus state flipped. Keyed idx*2+focus; cleared when lines are rebuilt / theme shown.
    const LINE_CACHE_MAX = 30; // v3: visible window + next verse-step window, both colors
    var _lineBmp as Lang.Dictionary = {};
    var _lineBmpGen as Lang.Number = 0;

    function clearLineCache() as Void {
        _preIdx = [] as Lang.Array;
        _lineBmp = {};
    }

    function drawVerseLineCached(dc as Graphics.Dc, y as Lang.Number, lineH as Lang.Number, idx as Lang.Number,
                                 ln as ScrollModel.Line, focusBook as Lang.Number,
                                 focusChapter as Lang.Number, focusVerse as Lang.Number) as Void {
        if (toast != null || !(Graphics has :createBufferedBitmap)) {
            drawVerseLine(dc, y, lineH, ln, focusBook, focusChapter, focusVerse);
            return;
        }
        var ref = ensureLineBmp(idx, ln, lineH, focusBook, focusChapter, focusVerse);
        if (ref == null) {
            drawVerseLine(dc, y, lineH, ln, focusBook, focusChapter, focusVerse);
            return;
        }
        dc.drawBitmap(_colLeft, y - 1, ref as Graphics.BufferedBitmapReference);
    }

    //! Cached bitmap for line idx in its focus state; renders it on a miss. Null = no bitmap.
    function ensureLineBmp(idx as Lang.Number, ln as ScrollModel.Line, lineH as Lang.Number,
                           focusBook as Lang.Number, focusChapter as Lang.Number, focusVerse as Lang.Number) {
        _lineHC = lineH;
        var isFocus = ln.book == focusBook && ln.chapter == focusChapter && ln.verse == focusVerse;
        var key = idx * 2 + (isFocus ? 1 : 0);
        var ref = _lineBmp[key];
        if (ref != null && (ref as Graphics.BufferedBitmapReference).get() != null) {
            return ref;
        }
        if (_lineBmp.size() >= LINE_CACHE_MAX) {
            evictLines();
        }
        ref = Graphics.createBufferedBitmap({:width => _colWidth, :height => lineH + 1});
        var bmp = (ref as Graphics.BufferedBitmapReference).get();
        if (bmp == null) {
            return null;
        }
        var bdc = (bmp as Graphics.BufferedBitmap).getDc();
        bdc.setColor(Palette.BG, Palette.BG);
        bdc.clear();
        // Draw at (0, 1) in bitmap space: same glyphs as the direct path (numY = y - 1).
        var saveLeft = _colLeft;
        var saveTop = _bandTop;
        _colLeft = 0;
        _bandTop = 0;
        drawVerseLine(bdc, 1, lineH, ln, focusBook, focusChapter, focusVerse);
        _colLeft = saveLeft;
        _bandTop = saveTop;
        _lineBmp[key] = ref;
        return ref;
    }

    // PRERENDER (v3): a verse step changes which verse is bright, so every visible line of
    // the next verse needs its other color variant. After each frame, idle ticks render the
    // lines the NEXT press will show (2 lines per tick), so the press itself is all blits.
    // POKE: PRERENDER_LINES_PER_TICK
    const PRERENDER_PER_TICK = 2;
    var _preTimer = null;
    var _preIdx as Lang.Array = [] as Lang.Array;
    var _preF as Lang.Dictionary or Null = null;
    var _lineHC as Lang.Number = 0;

    function schedulePrerender() as Void {
        // Chunked wrap still running: its timer repaints anyway; prerender after it (timer cap).
        if (_pendVerses != null || _continuationPending) {
            return;
        }
        if (toast != null || _lineHC == 0 || AppState.scroll.mode != ScrollModel.MODE_VERSE
            || !(Graphics has :createBufferedBitmap)) {
            return;
        }
        var sc = AppState.scroll;
        var save = sc.scrollOffset;
        sc.verseNext();
        var nOff = sc.scrollOffset;
        var f = resolveFocus();
        sc.scrollOffset = save;
        if (nOff == save) {
            return;
        }
        var fb = f[:book] as Lang.Number;
        var fc = f[:chapter] as Lang.Number;
        var fv = f[:verse] as Lang.Number;
        var list = [] as Lang.Array;
        var i;
        for (i = nOff; i <= nOff + sc.visibleCount && i < sc.lines.size(); i++) {
            var ln = sc.lines[i] as ScrollModel.Line;
            if (ln.kind != ScrollModel.KIND_VERSE) {
                continue;
            }
            var isF = ln.book == fb && ln.chapter == fc && ln.verse == fv;
            var ref = _lineBmp[i * 2 + (isF ? 1 : 0)];
            if (ref == null || (ref as Graphics.BufferedBitmapReference).get() == null) {
                list.add(i);
            }
        }
        _preIdx = list;
        _preF = f;
        if (list.size() > 0) {
            if (_preTimer == null) {
                _preTimer = new Timer.Timer();
            }
            (_preTimer as Timer.Timer).start(method(:onPrerender), 50, false);
        }
    }

    function onPrerender() as Void {
        var f = _preF;
        if (f == null || toast != null) {
            return;
        }
        var lines = AppState.scroll.lines;
        var n = 0;
        while (_preIdx.size() > 0 && n < PRERENDER_PER_TICK) {
            var i = _preIdx[0] as Lang.Number;
            _preIdx = _preIdx.slice(1, null);
            if (i < lines.size()) {
                ensureLineBmp(i, lines[i] as ScrollModel.Line, _lineHC, f[:book] as Lang.Number,
                              f[:chapter] as Lang.Number, f[:verse] as Lang.Number);
            }
            n++;
        }
        if (_preIdx.size() > 0) {
            (_preTimer as Timer.Timer).start(method(:onPrerender), 50, false);
        }
    }

    //! Drop cached lines farthest from the viewport.
    function evictLines() as Void {
        var keys = _lineBmp.keys();
        var lo = AppState.scroll.scrollOffset - 2;
        var hi = AppState.scroll.scrollOffset + 2 * AppState.scroll.visibleCount + 6;
        var i;
        for (i = 0; i < keys.size(); i++) {
            var li = (keys[i] as Lang.Number) / 2;
            if (li < lo || li > hi) {
                _lineBmp.remove(keys[i]);
            }
        }
        if (_lineBmp.size() >= LINE_CACHE_MAX) {
            _lineBmp = {};
        }
    }

    function drawVerseLine(dc as Graphics.Dc, y as Lang.Number, lineH as Lang.Number,
                           ln as ScrollModel.Line, focusBook as Lang.Number,
                           focusChapter as Lang.Number, focusVerse as Lang.Number) as Void {
        var x = _colLeft;
        var isFocus = ln.book == focusBook && ln.chapter == focusChapter && ln.verse == focusVerse;
        // Focus via color only (same system face) — BMFont weights reverted.
        var bodyColor = Palette.TEXT;
        if (!isFocus) {
            bodyColor = Palette.DIM_VERSE; // POKE: Palette.DIM_VERSE
        }
        // POKE: WORDS_OF_JESUS — if markup existed, bodyColor → Palette.JESUS for those runs.
        var bodyFace = _bodyFont;
        if (ln.isVerseStart) {
            // Gold system-font verse number (XTINY/TINY) — not a custom bold face.
            var num = ln.verse.toString();
            // PERF: opaque bg (band is solid BG) -> no per-glyph alpha blend.
            dc.setColor(tc(Palette.GOLD), Palette.BG);
            var numY = y - 1;
            if (numY < _bandTop) {
                numY = y;
            }
            dc.drawText(x, numY, _numFont, num, Graphics.TEXT_JUSTIFY_LEFT);
            var nw = _numW[ln.verse];
            if (nw == null) {
                nw = dc.getTextWidthInPixels(num, _numFont); // PERF: once per verse number
                _numW[ln.verse] = nw;
            }
            x += (nw as Lang.Number) + 4;
        }
        dc.setColor(tc(bodyColor), Palette.BG);
        dc.drawText(x, y, bodyFace, ln.text, Graphics.TEXT_JUSTIFY_LEFT);
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
        dc.setColor(tc(Palette.DIVIDER_RULE), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        if (labelLeft - (_colLeft + padX) > 4) {
            dc.drawLine(_colLeft + padX, ruleY, labelLeft, ruleY);
        }
        if ((_colLeft + _colWidth - padX) - labelRight > 4) {
            dc.drawLine(labelRight, ruleY, _colLeft + _colWidth - padX, ruleY);
        }
        dc.setColor(tc(Palette.GOLD), Graphics.COLOR_TRANSPARENT);
        dc.drawText(midX, y + (lineH - dc.getFontHeight(font)) / 2, font, label,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Two-row pyramid wrap (Dylan): row 1 (narrow chord) must be no wider than row 2.
    //! Picks the split with row1 <= row2, each inside its chord, that is most balanced
    //! (widest row 1). One row when the text fits row 1's chord. Null if no split fits.
    //! Three rows: row 1 fits c1 and is no wider than row 2 (pyramid) when possible;
    //! rows 2-3 via the two-row pyramid split. Null when nothing fits.
    function wrapThree(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition,
                       c1 as Lang.Number, c2 as Lang.Number, c3 as Lang.Number) as Lang.Array or Null {
        var words = ContentLoader.splitWords(text);
        var best = null;
        var bestScore = 0;
        var k;
        var a = "";
        for (k = 1; k < words.size() - 1; k++) {
            a = a.length() == 0 ? words[k - 1] as Lang.String : a + " " + words[k - 1];
            var wa = dc.getTextWidthInPixels(a, font);
            if (wa > c1) {
                break;
            }
            var rest = "";
            var i;
            for (i = k; i < words.size(); i++) {
                rest = rest.length() == 0 ? words[i] as Lang.String : rest + " " + words[i];
            }
            var two = RoundLayout.pyramidSplit(dc, rest, font, c2, c3);
            if (two == null) {
                continue;
            }
            var wb = dc.getTextWidthInPixels(two[0] as Lang.String, font);
            var score = wa <= wb ? 100000 + wa : 50000 - (wa - wb);
            if (best == null || score > bestScore) {
                best = [a, two[0], two[1]];
                bestScore = score;
            }
        }
        return best;
    }

    function wrapTwo(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition,
                     w1 as Lang.Number, w2 as Lang.Number) as Lang.Array or Null {
        if (dc.getTextWidthInPixels(text, font) <= w1) {
            return [text, ""];
        }
        var words = ContentLoader.splitWords(text);
        var best = null;
        var bestW1 = -1;
        var k;
        for (k = 1; k < words.size(); k++) {
            var a = "";
            var b = "";
            var i;
            for (i = 0; i < words.size(); i++) {
                if (i < k) {
                    a = a.length() == 0 ? words[i] as Lang.String : a + " " + words[i];
                } else {
                    b = b.length() == 0 ? words[i] as Lang.String : b + " " + words[i];
                }
            }
            var wa = dc.getTextWidthInPixels(a, font);
            var wb = dc.getTextWidthInPixels(b, font);
            if (wa <= w1 && wb <= w2 && wa <= wb && wa > bestW1) {
                best = [a, b];
                bestW1 = wa;
            }
        }
        if (best == null && dc.getTextWidthInPixels(text, font) <= w2) {
            return ["", text];
        }
        if (best == null) {
            best = RoundLayout.pyramidSplit(dc, text, font, w1, w2);
        }
        return best;
    }

    //! Toast dim: while a toast shows, the reader redraws in one dim gray under the pill.
    function tc(color as Lang.Number) as Lang.Number {
        return toast != null ? Palette.TOAST_DIM : color;
    }

    function ellipsizeToWidth(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition,
                              maxW as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(text, font) <= maxW) {
            return text;
        }
        var s = text;
        while (s.length() > 3) {
            s = s.substring(0, s.length() - 1);
            var trial = s.substring(0, s.length() - 2) + "..";
            if (dc.getTextWidthInPixels(trial, font) <= maxW) {
                return trial;
            }
        }
        return "..";
    }

    //! Snap scroll so verse N starts at band top (Menu2 Go to verse).
    function jumpToVerse(verse as Lang.Number) as Void {
        var lines = AppState.scroll.lines;
        var i;
        for (i = 0; i < lines.size(); i++) {
            var ln = lines[i] as ScrollModel.Line;
            // >= : a verse the BSB omits (Matt 17:21) lands on the next one present.
            if (ln.kind == ScrollModel.KIND_VERSE && ln.isVerseStart && ln.verse >= verse
                && ln.book == AppState.selectedBook && ln.chapter == AppState.selectedChapter) {
                AppState.scroll.scrollOffset = i;
                AppState.scroll.clampOffset();
                WatchUi.requestUpdate();
                return;
            }
        }
        // Not wrapped yet (chunked wrap still running): apply when its chunk lands.
        if (_pendVerses != null && _pendPrimary) {
            _pendingJump = verse;
        }
    }

    function resolveFocus() as Lang.Dictionary {
        // Boundary rule (Dylan): once a chapter divider has risen into the top half of the
        // band, the next chapter's verse 1 owns focus -> header, bottom ref, ring, dimming switch.
        var lines = AppState.scroll.lines;
        var half = (AppState.scroll.visibleCount + 1) / 2;
        var r;
        for (r = 1; r <= half; r++) {
            var di = AppState.scroll.scrollOffset + r;
            if (di >= lines.size()) {
                break;
            }
            var dl = lines[di] as ScrollModel.Line;
            if (dl.kind == ScrollModel.KIND_DIVIDER) {
                var j;
                for (j = di + 1; j < lines.size(); j++) {
                    var nl = lines[j] as ScrollModel.Line;
                    if (nl.kind == ScrollModel.KIND_VERSE) {
                        return { :book => nl.book, :chapter => nl.chapter, :verse => nl.verse };
                    }
                }
                break;
            }
        }
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
        if (_toastTimer == null) {
            _toastTimer = new Timer.Timer();
        }
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

    // POKE: SCROLL_STEP — buttons (onKey UP/DOWN) = one step (line, or verse start);
    // swipe = page in line mode. The page behaviors return false so the OS hands the
    // raw key / swipe to onKey / onSwipe and nothing steps twice (no TouchGuard flags).
    function onNextPage() as Lang.Boolean {
        return false;
    }

    function onPreviousPage() as Lang.Boolean {
        return false;
    }

    function step(dir as Lang.Number, page as Lang.Boolean) as Lang.Boolean {
        if (page) {
            AppState.scroll.page(dir);
        } else if (dir > 0) {
            AppState.scroll.next();
        } else {
            AppState.scroll.prev();
        }
        syncCurrentFromFocus();
        WatchUi.requestUpdate();
        return true;
    }

    function syncCurrentFromFocus() as Void {
        var f = _view.resolveFocus();
        AppState.selectedBook = f[:book] as Lang.Number;
        AppState.selectedChapter = f[:chapter] as Lang.Number;
    }

    // TAP FIX (same as lists): a tap is also mapped to onSelect; onSelect never acts, the
    // button arrives via onKey(ENTER), the tap via onTap. No TouchGuard flag can go stale
    // and swallow the next press (it ate the first Select after tapping a chapter).
    function onSelect() as Lang.Boolean {
        return false;
    }

    function onKey(evt as WatchUi.KeyEvent) as Lang.Boolean {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ENTER) {
            if (InputGate.accept(_view.shownAt, System.getTimer())) {
                _view.openMenu();
            }
            return true;
        }
        if (k == WatchUi.KEY_DOWN) {
            return step(1, false);
        }
        if (k == WatchUi.KEY_UP) {
            return step(-1, false);
        }
        return false;
    }

    function onHold(evt) as Lang.Boolean {
        if (InputGate.accept(_view.shownAt, System.getTimer())) {
            _view.bookmarkFocusedVerse();
        }
        return true;
    }

    function onTap(evt) as Lang.Boolean {
        // Taps meant for the grid (mash during the open flash) must not open this menu.
        if (InputGate.accept(_view.shownAt, System.getTimer())) {
            _view.openMenu();
        }
        return true;
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            return step(1, true);
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            return step(-1, true);
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
