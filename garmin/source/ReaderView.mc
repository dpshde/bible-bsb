using Toybox.Attention;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

//! Center-band lens reader. First paint wraps only the verses on screen and draws them
//! directly; the rest of the chapter, the next chapter and the per-line bitmaps are built
//! by one idle Timer in short time-boxed slices that never repaint (v6: instant open).
//! Every verse starts on a new line (no run-on paragraph); gold inline numbers.
//! Built-in watch fonts only (BMFont weighting reverted — see docs/font-budget.md); v7 headings
//! are a heavier built-in face than the verse body (Faces).
class ReaderView extends WatchUi.View {
    var toast as Lang.String or Null = null;
    // v9 range bookmark: selStart > 0 while verses selStart..selEnd of selBook/selCh are shown
    // gold. selPick = an interactive pick (UP/DOWN extend, START saves, BACK cancels); otherwise
    // it is the brief highlight of an opened range bookmark, cleared by the first input.
    var selStart as Lang.Number = -1;
    var selEnd as Lang.Number = -1;
    var selBook as Lang.Number = -1;
    var selCh as Lang.Number = -1;
    var selPick as Lang.Boolean = false;
    var _toastTimer as Timer.Timer or Null = null;
    var _laidOut as Lang.Boolean = false;
    var _bmpBg as Lang.Number = -1; // Palette.BG the cached line bitmaps were drawn on
    // v7: verse text in the regular body face, headings heavier (Faces).
    var _bodyFont as Graphics.FontType = Graphics.FONT_XTINY;
    var _numFont as Graphics.FontType = Graphics.FONT_XTINY;
    var _colLeft as Lang.Number = 0;
    var _colWidth as Lang.Number = 0;
    var _bandTop as Lang.Number = 0;
    var _bandBottom as Lang.Number = 0;
    var _metaBottom as Lang.Number = 0;
    var _previewTop as Lang.Number = 0;
    var _wrapBook as Lang.Number = 0;
    var _wrapChapter as Lang.Number = 0;
    var _continuationPending as Lang.Boolean = false;
    // Incremental wrap state (stock 240k watchdog: Psalm 119 = 176 verses tripped eager wrap).
    // POKE: FIRST_PAINT_LINES — lines wrapped before the first paint (a screenful + 1 step).
    const FIRST_PAINT_LINES = 9;
    // POKE: AHEAD_LINES — a scroll step first makes sure this many lines exist below the
    // offset (synchronous only when the idle wrap fell behind; normally a no-op).
    const AHEAD_LINES = 14;
    // POKE: IDLE_TICK_MS / IDLE_BUDGET_MS — one Timer does all background work in slices of
    // at most IDLE_BUDGET_MS, so a button press waits at most one slice. No slice repaints.
    const IDLE_TICK_MS = 50; // CIQ minimum timer period
    const IDLE_BUDGET_MS = 10;
    // POKE: CONT_IDLE_MS — the next chapter (one loadResource) is fetched only after this long
    // without input, or when scrolling reaches the end of the wrapped text.
    const CONT_IDLE_MS = 700;
    var _idleTimer as Timer.Timer or Null = null;
    var _lastInputAt as Lang.Number = 0;
    var _lastVerse as Lang.Number = 0; // verse number of the last wrapped line
    var _pendVerses as Lang.Array or Null = null;
    var _pendBook as Lang.Number = 0;
    var _pendChapter as Lang.Number = 0;
    var _pendIdx as Lang.Number = 0;
    var _pendPrimary as Lang.Boolean = false;
    var _pendingJump as Lang.Number = 0;
    var _verseCount as Lang.Number = 0;
    var shownAt as Lang.Number = 0; // InputGate: when this reader appeared

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        if (!_laidOut) { // a reader prepared on the grid (ReaderPrep) is already laid out
            rebuildLines(dc);
            _laidOut = true;
        }
    }

    // ---- Prepared open (v6, ReaderPrep) --------------------------------------------------
    var _prepping as Lang.Boolean = false;
    var _prepLines as Lang.Array or Null = null;
    var _prepOffset as Lang.Number = 0;
    var _prepSections as Lang.Array or Null = null;
    var _prepQueued as Lang.Boolean = false;

    //! Resume verse a fresh open of (book, chapter) would land on (0 = top).
    static function targetFor(book as Lang.Number, chapter as Lang.Number) as Lang.Number {
        if (LastReadApp.resumeVerse > 1) {
            var lp = LastReadApp.pending;
            if (lp != null && lp[0] == book && lp[1] == chapter) {
                return LastReadApp.resumeVerse;
            }
        }
        return 0;
    }

    //! Lay out (book, chapter) off screen while the grid shows it: load + wrap the first
    //! screenful. Bitmaps follow in prepStep slices. Nothing here repaints.
    function prebuild(book as Lang.Number, chapter as Lang.Number) as Lang.Boolean {
        var mdc = MeasureDc.get();
        if (mdc == null) {
            return false;
        }
        _prepping = true;
        var sb = AppState.selectedBook;
        var sch = AppState.selectedChapter;
        AppState.selectedBook = book;
        AppState.selectedChapter = chapter;
        rebuildLines(mdc as Graphics.Dc);
        AppState.selectedBook = sb;
        AppState.selectedChapter = sch;
        _laidOut = true;
        _prepLines = AppState.scroll.lines;
        _prepOffset = AppState.scroll.scrollOffset;
        _prepSections = AppState.sections;
        return true;
    }

    //! One prep slice: heading + the first screen's line bitmaps (+ the next press's).
    //! Returns true while work remains.
    function prepStep(budgetMs as Lang.Number) as Lang.Boolean {
        var t0 = System.getTimer();
        var sc = AppState.scroll;
        if (sc.lines != _prepLines) {
            return false; // another reader rebuilt the shared buffer: stale, open will rebuild
        }
        if (!_prepQueued) {
            _prepQueued = true;
            var mdc = MeasureDc.get();
            if (mdc == null) {
                return false;
            }
            var f = resolveFocus();
            var fb = f[:book] as Lang.Number;
            var fc = f[:chapter] as Lang.Number;
            var fv = f[:verse] as Lang.Number;
            layoutHead(mdc as Graphics.Dc, MeasureDc.screenW(), MeasureDc.screenH(), headTextFor(fb, fc, fv));
            _headMiss = Graphics has :createBufferedBitmap;
            var q = [[-1, fb, fc, fv]] as Lang.Array;
            var i;
            for (i = sc.scrollOffset; i <= sc.scrollOffset + sc.visibleCount && i < sc.lines.size(); i++) {
                if ((sc.lines[i] as ScrollModel.Line).kind == ScrollModel.KIND_VERSE) {
                    q.add([i, fb, fc, fv]);
                }
            }
            queueStep(q, 1);
            _preQ = q;
            return true;
        }
        if (_headMiss) {
            renderHeadBmp();
        }
        while (_preQ.size() > 0 && System.getTimer() - t0 < budgetMs) {
            var e = _preQ[0] as Lang.Array;
            _preQ = _preQ.slice(1, null);
            renderQueued(e);
        }
        return _preQ.size() > 0;
    }

    //! The prepared reader is being opened: put its buffer back in the shared scroll state.
    function adoptPrepared() as Void {
        _prepping = false;
        if (_prepLines != null) {
            AppState.scroll.lines = _prepLines as Lang.Array;
            AppState.scroll.scrollOffset = _prepOffset;
            AppState.sections = _prepSections != null ? _prepSections as Lang.Array : [] as Lang.Array;
        }
        _prepLines = null;
        _prepSections = null;
        LastReadApp.resumeVerse = 0;
    }

    function onShow() as Void {
        shownAt = System.getTimer();
        AppState.scroll.mode = AppState.scroll.loadMode();
        if (_bmpBg != Palette.BG) {
            clearLineCache(); // theme toggled while the menu was up
            _headBmp = null;
            _refBmp = {};
            _bmpBg = Palette.BG;
        }
        // Resume background work paused while Menu2 / another view was on top.
        if (_laidOut) {
            scheduleIdle(IDLE_TICK_MS);
        }
    }

    function onHide() as Void {
        clearToastTimer();
        stopIdle();
        _preQ = [] as Lang.Array;
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
        // Screen size, not dc size: a prepared reader is laid out on the 1x1 MeasureDc.
        var w = MeasureDc.screenW();
        var h = MeasureDc.screenH();
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
        _bodyFont = Faces.body();
        _numFont = _bodyFont;

        var lines = [] as Lang.Array;
        clearLineCache();
        AppState.sections = [];
        AppState.scroll.lines = lines;
        AppState.scroll.scrollOffset = 0;
        _continuationPending = false;
        _pendingJump = 0;
        _lastVerse = 0;
        // v6: the word-width memo survives chapter opens (same face, same widths); it is
        // only trimmed when large, so the next chapter's common words cost no measuring.
        ContentLoader.trimWordCache();
        startChapterWrap(_wrapBook, _wrapChapter, true);
        // Resume last-read verse once (relaunch into the same chapter): wrap through it now
        // so the first paint already shows it (no visible jump a tick later).
        var target = targetFor(_wrapBook, _wrapChapter);
        if (!_prepping) {
            LastReadApp.resumeVerse = 0;
        }
        _bmpBg = Palette.BG;
        wrapSome(dc, FIRST_PAINT_LINES, target, 0, false);
        if (target > 1) {
            jumpToVerseIn(target, _wrapBook, _wrapChapter);
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
        _lineHC = lineH; // line-bitmap height (a prepared reader builds bitmaps before any frame)
        var bandH = _bandBottom - _bandTop;
        AppState.scroll.visibleCount = bandH / lineH;
        if (AppState.scroll.visibleCount < 1) {
            AppState.scroll.visibleCount = 1;
        }
        if (AppState.scroll.visibleCount > 5) {
            AppState.scroll.visibleCount = 5; // lens: max ~4–5 lines
        }
        AppState.scroll.clampOffset();
        scheduleIdle(IDLE_TICK_MS);
    }

    //! Primary chapter fully wrapped: queue the continuation chapter (or the End line).
    function finishPrimary() as Void {
        var nxt = ChapterNav.nextChapter(_wrapBook, _wrapChapter);
        if (nxt != null && ContentLoader.hasChapter(nxt.book, nxt.chapter)) {
            _continuationPending = true;
        } else if (nxt == null && ChapterNav.isBibleEnd(_wrapBook, _wrapChapter)) {
            AppState.scroll.lines.add(new ScrollModel.Line(
                ScrollModel.KIND_END, _wrapBook, _wrapChapter, 0, "— End —", false));
        }
    }

    //! Divider + start wrapping the next chapter (its loadResource is the costly part).
    function startContinuation() as Void {
        _continuationPending = false;
        var nxt = ChapterNav.nextChapter(_wrapBook, _wrapChapter);
        if (nxt == null || !ContentLoader.hasChapter(nxt.book, nxt.chapter)) {
            return;
        }
        appendDivider(AppState.scroll.lines, nxt.book, nxt.chapter);
        startChapterWrap(nxt.book, nxt.chapter, false);
    }

    //! Wrap one verse at a time until: >= minLines lines exist AND verse untilVerse of the
    //! primary chapter is wrapped (plus a screenful after it), or budgetMs ran out (0 = none),
    //! or there is nothing left. Loads the continuation chapter only if allowCont.
    //! Returns true if any line was added.
    function wrapSome(dc as Graphics.Dc, minLines as Lang.Number, untilVerse as Lang.Number,
                      budgetMs as Lang.Number, allowCont as Lang.Boolean) as Lang.Boolean {
        var t0 = System.getTimer();
        var lines = AppState.scroll.lines;
        var before = lines.size();
        while (true) {
            var needLines = lines.size() < minLines;
            var needVerse = untilVerse > 0 && _pendPrimary && _pendVerses != null
                && _lastVerse < untilVerse + 3;
            if (!needLines && !needVerse) {
                break;
            }
            if (budgetMs > 0 && System.getTimer() - t0 >= budgetMs) {
                break;
            }
            if (_pendVerses == null) {
                if (_continuationPending && needLines && allowCont) {
                    startContinuation();
                    continue;
                }
                break;
            }
            wrapOne(dc);
        }
        return lines.size() != before;
    }

    //! Wrap the next pending verse; finishing the primary chapter queues the continuation.
    function wrapOne(dc as Graphics.Dc) as Void {
        var verses = _pendVerses;
        if (verses == null) {
            return;
        }
        appendVerseRange(dc, AppState.scroll.lines, _pendBook, _pendChapter, verses, _pendIdx, _pendIdx + 1, _colWidth);
        var lines = AppState.scroll.lines;
        _lastVerse = lines.size() > 0 ? (lines[lines.size() - 1] as ScrollModel.Line).verse : 0;
        _pendIdx++;
        if (_pendIdx >= verses.size()) {
            _pendVerses = null;
            if (_pendPrimary) {
                finishPrimary();
            }
        }
        if (_pendingJump > 0 && _pendPrimary) {
            var j = _pendingJump;
            _pendingJump = 0;
            jumpToVerse(j);
        }
    }

    //! A scroll step is about to happen: make sure the lines it can reach exist (only does
    //! work when the idle wrap fell behind a fast scroller).
    function ensureAhead() as Void {
        var sc = AppState.scroll;
        var need = sc.scrollOffset + AHEAD_LINES;
        if (sc.lines.size() >= need || (_pendVerses == null && !_continuationPending)) {
            return;
        }
        var mdc = MeasureDc.get();
        if (mdc != null) {
            wrapSome(mdc as Graphics.Dc, need, 0, 0, true);
        }
    }

    function noteInput() as Void {
        _lastInputAt = System.getTimer();
    }

    // ---- Idle worker (one reused Timer: CIQ caps live timers, "Too Many Timers Error") ----
    function scheduleIdle(ms as Lang.Number) as Void {
        if (_prepping) {
            return; // ReaderPrep drives a prepared reader's slices until it is opened
        }
        if (_idleTimer == null) {
            _idleTimer = new Timer.Timer();
        } else {
            (_idleTimer as Timer.Timer).stop();
        }
        (_idleTimer as Timer.Timer).start(method(:onIdle), ms, false);
    }

    function stopIdle() as Void {
        if (_idleTimer != null) {
            (_idleTimer as Timer.Timer).stop();
        }
    }

    //! One slice: (1) line bitmaps for the next press / the current screen, (2) wrap more of
    //! the pending chapter, (3) after CONT_IDLE_MS without input, load the next chapter.
    //! Never requests a paint unless freshly wrapped lines land inside the visible band.
    function onIdle() as Void {
        var t0 = System.getTimer();
        var pt0 = Perf.start();
        var tag = "none";
        var sc = AppState.scroll;
        if (_headMiss && toast == null) {
            tag = "head";
            renderHeadBmp();
        }
        if (_preQ.size() > 0 && toast == null) {
            tag = "bitmaps";
            while (_preQ.size() > 0 && System.getTimer() - t0 < IDLE_BUDGET_MS) {
                var q = _preQ[0] as Lang.Array;
                _preQ = _preQ.slice(1, null);
                renderQueued(q);
            }
        } else if (_pendVerses != null) {
            tag = "wrap";
            var mdc = MeasureDc.get();
            if (mdc != null) {
                var shown = sc.lines.size() <= sc.scrollOffset + sc.visibleCount + 2;
                if (wrapSome(mdc as Graphics.Dc, 0x7fffffff, 0, IDLE_BUDGET_MS, false) && shown) {
                    WatchUi.requestUpdate();
                }
            }
        } else if (_continuationPending) {
            var quiet = System.getTimer() - _lastInputAt;
            if (quiet < CONT_IDLE_MS) {
                scheduleIdle(CONT_IDLE_MS - quiet > IDLE_TICK_MS ? CONT_IDLE_MS - quiet : IDLE_TICK_MS);
                return;
            }
            tag = "load";
            startContinuation();
            var shown2 = sc.lines.size() <= sc.scrollOffset + sc.visibleCount + 2;
            if (shown2) {
                WatchUi.requestUpdate();
            }
        }
        Perf.idle(tag, pt0);
        if (_headMiss || _preQ.size() > 0 || _pendVerses != null || _continuationPending) {
            scheduleIdle(IDLE_TICK_MS);
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
        if (!(_bodyFont instanceof Lang.Number)) {
            return; // vector body face: no system size ladder to grow along
        }
        var larger = RoundLayout.growFont(_bodyFont as Graphics.FontDefinition);
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

    //! Heading text for the focused verse (sticky section title, else "Book N").
    function headTextFor(book as Lang.Number, chapter as Lang.Number, verse as Lang.Number) as Lang.String {
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
        return (sticky != null && (sticky as Lang.String).length() > 0)
            ? sticky as Lang.String : Books.name(book) + " " + chapter;
    }

    var _row1Y as Lang.Number = 0;
    var _row2Y as Lang.Number = 0;
    var _row3Y as Lang.Number = 0;
    var _headBottom as Lang.Number = 0;
    var _headBmp = null;          // v6: heading rows rendered once per heading text
    var _headBmpBg as Lang.Number = -1;
    var _headMiss as Lang.Boolean = false;

    //! Measure the heading pyramid for headText (cached by text: no measuring per frame).
    function layoutHead(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, headText as Lang.String) as Void {
        if (_headKey != null && (_headKey as Lang.String).equals(headText)) {
            return;
        }
        var headFont = Graphics.FONT_XTINY;
        var headH = dc.getFontHeight(headFont);
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
        var three = null;
        var rows = wrapTwo(dc, headText.toUpper(), headFont, c1, c2);
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
        _row1Y = row1Y;
        _row2Y = row2Y;
        _row3Y = row3Y;
        var hb = row1Y;
        if ((_headRows[0] as Lang.String).length() > 0) {
            hb = row1Y + headH;
        }
        if ((_headRows[1] as Lang.String).length() > 0) {
            hb = row2Y + headH;
        }
        if (three != null && (three[2] as Lang.String).length() > 0) {
            hb = row3Y + headH;
        }
        _headBottom = hb;
        _headBmp = null;
    }

    //! Heading rows at (cx, y - yOff): the frame draws at yOff 0, the bitmap at yOff row1Y.
    function drawHeadRows(dc as Graphics.Dc, cx as Lang.Number, yOff as Lang.Number) as Void {
        var headFont = Graphics.FONT_XTINY;
        // POKE: HEAD_COLOR — heading gold (upstream) vs MUTED, since the bottom ref is gold too.
        dc.setColor(tc(Palette.GOLD), Palette.BG);
        if ((_headRows[0] as Lang.String).length() > 0) {
            dc.drawText(cx, _row1Y - yOff, Faces.light(headFont), _headRows[0] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
        if ((_headRows[1] as Lang.String).length() > 0) {
            dc.drawText(cx, _row2Y - yOff, Faces.light(headFont), _headRows[1] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
        var three = _headThree;
        if (three != null && (three[2] as Lang.String).length() > 0) {
            dc.drawText(cx, _row3Y - yOff, Faces.light(headFont), three[2] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawHead(dc as Graphics.Dc, w as Lang.Number) as Void {
        var ref = _headBmp;
        if (toast == null && ref != null && _headBmpBg == Palette.BG
            && (ref as Graphics.BufferedBitmapReference).get() != null) {
            dc.drawBitmap(0, _row1Y, ref as Graphics.BufferedBitmapReference);
            return;
        }
        drawHeadRows(dc, w / 2, 0);
        _headMiss = toast == null && (Graphics has :createBufferedBitmap);
    }

    //! Idle: render the current heading into a bitmap (full width, rows' height).
    function renderHeadBmp() as Void {
        _headMiss = false;
        var hh = _headBottom - _row1Y;
        var w = MeasureDc.screenW();
        if (hh <= 0 || _headKey == null) {
            return;
        }
        var ref = Graphics.createBufferedBitmap({:width => w, :height => hh});
        var bmp = (ref as Graphics.BufferedBitmapReference).get();
        if (bmp == null) {
            return;
        }
        var bdc = (bmp as Graphics.BufferedBitmap).getDc();
        bdc.setColor(Palette.BG, Palette.BG);
        bdc.clear();
        drawHeadRows(bdc, w / 2, _row1Y);
        _headBmp = ref;
        _headBmpBg = Palette.BG;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var t0 = Perf.start();
        onUpdateImpl(dc);
        schedulePrerender();
        Perf.end("reader", t0);
        Perf.firstPaint("reader");
    }

    function onUpdateImpl(dc as Graphics.Dc) as Void {
        Perf.segStart();
        if (!_laidOut) {
            rebuildLines(dc);
            _laidOut = true;
        }
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
        layoutHead(dc, w, h, headTextFor(book, chapter, verse));
        drawHead(dc, w);
        // POKE: HEAD_BAND_GAP — px between heading block and reading band.
        if (_bandTop < _headBottom + 3) {
            _bandTop = _headBottom + 3;
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
        if (selStart > 0) {
            preview = rangeRef();
        }
        // v6: the ref is a cached bitmap per verse (next/previous built on idle slices).
        var rb = (toast == null && selStart <= 0) ? _refBmp[rk] : null;
        if (rb != null && ((rb as Lang.Array)[0] as Graphics.BufferedBitmapReference).get() != null) {
            var rw = (rb as Lang.Array)[1] as Lang.Number;
            dc.drawBitmap(w / 2 - rw / 2, previewY, (rb as Lang.Array)[0] as Graphics.BufferedBitmapReference);
        } else {
            dc.drawText(w / 2, previewY, Faces.light(previewFont), preview, Graphics.TEXT_JUSTIFY_CENTER);
            if (toast == null && selStart <= 0 && (Graphics has :createBufferedBitmap)) {
                _missQ.add([-1, book, chapter, verse]);
            }
        }
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
    const LINE_CACHE_MAX = 36; // v6: visible window + next AND previous step, both colors
    var _lineBmp as Lang.Dictionary = {};
    var _lineBmpGen as Lang.Number = 0;

    function clearLineCache() as Void {
        _preQ = [] as Lang.Array;
        _missQ = [] as Lang.Array;
        _lineBmp = {};
    }

    function drawVerseLineCached(dc as Graphics.Dc, y as Lang.Number, lineH as Lang.Number, idx as Lang.Number,
                                 ln as ScrollModel.Line, focusBook as Lang.Number,
                                 focusChapter as Lang.Number, focusVerse as Lang.Number) as Void {
        if (toast != null || selStart > 0 || !(Graphics has :createBufferedBitmap)) {
            drawVerseLine(dc, y, lineH, ln, focusBook, focusChapter, focusVerse);
            return;
        }
        // v6: a frame only blits; a line without a bitmap is drawn directly (cheaper than
        // allocating + rasterizing + blitting) and its bitmap is built on an idle slice.
        _lineHC = lineH;
        var isFocus = ln.book == focusBook && ln.chapter == focusChapter && ln.verse == focusVerse;
        var ref = _lineBmp[idx * 2 + (isFocus ? 1 : 0)];
        if (ref != null && (ref as Graphics.BufferedBitmapReference).get() != null) {
            dc.drawBitmap(_colLeft, y - 1, ref as Graphics.BufferedBitmapReference);
            return;
        }
        drawVerseLine(dc, y, lineH, ln, focusBook, focusChapter, focusVerse);
        _missQ.add([idx, focusBook, focusChapter, focusVerse]);
    }

    //! Cached bitmap for line idx in its focus state; renders it on a miss. Null = no bitmap.
    function ensureLineBmp(idx as Lang.Number, ln as ScrollModel.Line, lineH as Lang.Number,
                           focusBook as Lang.Number, focusChapter as Lang.Number, focusVerse as Lang.Number) {
        if (lineH <= 0) {
            return null;
        }
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

    // PRERENDER (v3, v6): a verse step changes which verse is bright, so every visible line
    // of the next verse needs its other color variant. After each frame the idle worker
    // renders, in order: the lines the NEXT press will show, the lines this frame drew
    // directly (misses), then the lines the PREVIOUS press would show. Queue entries are
    // [lineIdx, focusBook, focusChapter, focusVerse].
    var _preQ as Lang.Array = [] as Lang.Array;
    var _missQ as Lang.Array = [] as Lang.Array;
    var _lineHC as Lang.Number = 0;

    function schedulePrerender() as Void {
        var misses = _missQ;
        _missQ = [] as Lang.Array;
        if (toast != null || selStart > 0 || _lineHC == 0 || !(Graphics has :createBufferedBitmap)) {
            return;
        }
        var q = [] as Lang.Array;
        queueStep(q, 1);
        var i;
        for (i = 0; i < misses.size(); i++) {
            q.add(misses[i]);
        }
        queueStep(q, -1);
        _preQ = q;
        if (q.size() > 0 || _headMiss) {
            scheduleIdle(IDLE_TICK_MS);
        }
    }

    // POKE: REF_CACHE_MAX — bottom-ref bitmaps kept (current, next, previous + slack).
    const REF_CACHE_MAX = 8;
    var _refBmp as Lang.Dictionary = {}; // ref key -> [BufferedBitmapReference, width]

    function renderRefBmp(b as Lang.Number, c as Lang.Number, v as Lang.Number) as Void {
        var rk = (b * 1000 + c) * 1000 + v;
        var have = _refBmp[rk];
        if (have != null && ((have as Lang.Array)[0] as Graphics.BufferedBitmapReference).get() != null) {
            return;
        }
        var mdc = MeasureDc.get();
        if (mdc == null) {
            return;
        }
        var f = Graphics.FONT_XTINY;
        var text = Books.refLabel(b, c, v);
        var tw = (mdc as Graphics.Dc).getTextWidthInPixels(text, f) + 4;
        var fh = (mdc as Graphics.Dc).getFontHeight(f);
        if (_refBmp.size() >= REF_CACHE_MAX) {
            _refBmp = {};
        }
        var ref = Graphics.createBufferedBitmap({:width => tw, :height => fh});
        var bmp = (ref as Graphics.BufferedBitmapReference).get();
        if (bmp == null) {
            return;
        }
        var bdc = (bmp as Graphics.BufferedBitmap).getDc();
        bdc.setColor(Palette.BG, Palette.BG);
        bdc.clear();
        bdc.setColor(Palette.GOLD, Palette.BG);
        bdc.drawText(tw / 2, 0, Faces.light(f), text, Graphics.TEXT_JUSTIFY_CENTER);
        _refBmp[rk] = [ref, tw];
    }

    //! Build one queued bitmap: [lineIdx, b, c, v] (lineIdx -1 = the bottom ref for b c:v).
    function renderQueued(e as Lang.Array) as Void {
        var i = e[0] as Lang.Number;
        if (i < 0) {
            renderRefBmp(e[1] as Lang.Number, e[2] as Lang.Number, e[3] as Lang.Number);
            return;
        }
        var lines = AppState.scroll.lines;
        if (i < lines.size()) {
            ensureLineBmp(i, lines[i] as ScrollModel.Line, _lineHC, e[1] as Lang.Number,
                          e[2] as Lang.Number, e[3] as Lang.Number);
        }
    }

    //! Queue the uncached lines one step in dir (+1 next, -1 previous) would show.
    function queueStep(q as Lang.Array, dir as Lang.Number) as Void {
        var sc = AppState.scroll;
        var save = sc.scrollOffset;
        if (dir > 0) {
            sc.next();
        } else {
            sc.prev();
        }
        var nOff = sc.scrollOffset;
        var f = resolveFocus();
        sc.scrollOffset = save;
        if (nOff == save) {
            return;
        }
        var fb = f[:book] as Lang.Number;
        var fc = f[:chapter] as Lang.Number;
        var fv = f[:verse] as Lang.Number;
        if (_refBmp[(fb * 1000 + fc) * 1000 + fv] == null) {
            q.add([-1, fb, fc, fv]);
        }
        var i;
        for (i = nOff; i <= nOff + sc.visibleCount && i < sc.lines.size(); i++) {
            var ln = sc.lines[i] as ScrollModel.Line;
            if (ln.kind != ScrollModel.KIND_VERSE) {
                continue;
            }
            var isF = ln.book == fb && ln.chapter == fc && ln.verse == fv;
            var ref = _lineBmp[i * 2 + (isF ? 1 : 0)];
            if (ref == null || (ref as Graphics.BufferedBitmapReference).get() == null) {
                q.add([i, fb, fc, fv]);
            }
        }
    }

    //! Drop cached lines farthest from the viewport.
    function evictLines() as Void {
        var keys = _lineBmp.keys();
        var lo = AppState.scroll.scrollOffset - AppState.scroll.visibleCount - 4;
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
        if (selStart > 0) {
            // v9: selected verses gold, every other verse dimmed (same face, colour only).
            bodyColor = inSel(ln) ? Palette.GOLD : Palette.DIM_VERSE;
        } else if (!isFocus) {
            bodyColor = Palette.DIM_VERSE; // POKE: Palette.DIM_VERSE
        }
        // POKE: WORDS_OF_JESUS — if markup existed, bodyColor → Palette.JESUS for those runs.
        var bodyFace = _bodyFont;
        if (ln.isVerseStart) {
            // Gold system-font verse number (XTINY/TINY) — not a custom bold face.
            var num = ln.verse.toString();
            // PERF: opaque bg (band is solid BG) -> no per-glyph alpha blend.
            dc.setColor(tc(Palette.GOLD), Palette.BG);
            // 1 px above the body baseline, exactly as the cached line bitmap places it, so a
            // line drawn directly (cache miss) and its later bitmap are pixel-identical.
            var numY = y - 1;
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
        Faces.drawHead(dc, midX, y + (lineH - dc.getFontHeight(font)) / 2, font, label,
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
        jumpToVerseIn(verse, AppState.selectedBook, AppState.selectedChapter);
    }

    function jumpToVerseIn(verse as Lang.Number, book as Lang.Number, chapter as Lang.Number) as Void {
        var lines = AppState.scroll.lines;
        var i;
        for (i = 0; i < lines.size(); i++) {
            var ln = lines[i] as ScrollModel.Line;
            // >= : a verse the BSB omits (Matt 17:21) lands on the next one present.
            if (ln.kind == ScrollModel.KIND_VERSE && ln.isVerseStart && ln.verse >= verse
                && ln.book == book && ln.chapter == chapter) {
                AppState.scroll.scrollOffset = i;
                AppState.scroll.clampOffset();
                WatchUi.requestUpdate();
                return;
            }
        }
        // Not wrapped yet (idle wrap still running): wrap through it now, then retry once.
        if (_pendVerses != null && _pendPrimary) {
            var mdc = MeasureDc.get();
            if (mdc == null) {
                _pendingJump = verse; // applied when the wrap reaches it
                return;
            }
            wrapSome(mdc as Graphics.Dc, 0, verse, 0, false);
            var k;
            for (k = 0; k < lines.size(); k++) {
                var l2 = lines[k] as ScrollModel.Line;
                if (l2.kind == ScrollModel.KIND_VERSE && l2.isVerseStart && l2.verse >= verse
                    && l2.book == book && l2.chapter == chapter) {
                    AppState.scroll.scrollOffset = k;
                    AppState.scroll.clampOffset();
                    WatchUi.requestUpdate();
                    return;
                }
            }
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

    // ---- v9 range bookmarks -------------------------------------------------------------
    function inSel(ln as ScrollModel.Line) as Lang.Boolean {
        return ln.book == selBook && ln.chapter == selCh && ln.verse >= selStart && ln.verse <= selEnd;
    }

    //! Bottom ref while a range shows: "GEN 1:1–3".
    function rangeRef() as Lang.String {
        var r = Books.refLabel(selBook, selCh, selStart);
        return selEnd > selStart ? r + "–" + selEnd : r;
    }

    //! Start a pick on the focused verse (a lone verse is a valid range: START saves it).
    function startRange() as Void {
        var f = resolveFocus();
        var v = f[:verse] as Lang.Number;
        if (v <= 0) {
            return;
        }
        selBook = f[:book] as Lang.Number;
        selCh = f[:chapter] as Lang.Number;
        selStart = v;
        selEnd = v;
        selPick = true;
        Feedback.step();
        WatchUi.requestUpdate();
    }

    //! Highlight an opened range bookmark until the first input (no pick).
    function showRange(book as Lang.Number, chapter as Lang.Number, start as Lang.Number, end as Lang.Number) as Void {
        selBook = book;
        selCh = chapter;
        selStart = start;
        selEnd = end;
        selPick = false;
    }

    function clearRange() as Void {
        if (selStart > 0) {
            selStart = -1;
            selEnd = -1;
            selPick = false;
            WatchUi.requestUpdate();
        }
    }

    //! [first, last] line index of a verse in the buffer, or null when it is not loaded.
    function verseLines(book as Lang.Number, chapter as Lang.Number, v as Lang.Number) as Lang.Array or Null {
        var lines = AppState.scroll.lines;
        var first = -1;
        var last = -1;
        var i;
        for (i = 0; i < lines.size(); i++) {
            var ln = lines[i] as ScrollModel.Line;
            if (ln.kind == ScrollModel.KIND_VERSE && ln.verse == v && ln.chapter == chapter && ln.book == book) {
                if (first < 0) {
                    first = i;
                }
                last = i;
            } else if (first >= 0) {
                break;
            }
        }
        return first < 0 ? null : [first, last];
    }

    //! DOWN/swipe up grows the range by a verse, UP/swipe down shrinks it (never below the start
    //! verse, never past the chapter's last verse). The band scrolls to keep the end in view.
    function extendRange(dir as Lang.Number) as Void {
        var e = selEnd + dir;
        if (e < selStart) {
            return;
        }
        var r = verseLines(selBook, selCh, e);
        if (r == null && dir > 0) {
            ensureAhead();
            r = verseLines(selBook, selCh, e);
        }
        if (r == null) {
            return; // end of chapter (ranges stay in one chapter)
        }
        selEnd = e;
        var sm = AppState.scroll;
        var vis = sm.visibleCount > 2 ? sm.visibleCount - 1 : 1;
        if (dir > 0 && (r[1] as Lang.Number) > sm.scrollOffset + vis - 1) {
            // Scroll by whole verses (like verse mode): the top line is always a verse start, so
            // the band never opens on the tail of a verse, and focus after saving is that verse.
            var want = (r[1] as Lang.Number) - vis + 1;
            var top = r[0] as Lang.Number;
            var k;
            for (k = e - 1; k >= selStart; k--) {
                var rk = verseLines(selBook, selCh, k);
                if (rk == null || (rk[0] as Lang.Number) < want) {
                    break;
                }
                top = rk[0] as Lang.Number;
            }
            sm.scrollOffset = top;
        } else if (dir < 0 && (r[0] as Lang.Number) < sm.scrollOffset) {
            sm.scrollOffset = r[0] as Lang.Number;
        }
        sm.clampOffset();
        Feedback.step();
        WatchUi.requestUpdate();
    }

    //! START / tap: save the range; the toast pill confirms.
    function confirmRange() as Void {
        var result = Bookmarks.addRange(selBook, selCh, selStart, selEnd);
        selStart = -1;
        selEnd = -1;
        selPick = false;
        if (result == :added) {
            showToast("Bookmarked");
        } else if (result == :exists) {
            showToast("Already saved");
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

    static var pendingRange as Lang.Array or Null = null; // [book, chapter, start, end]

    static function openFor(book as Lang.Number, chapter as Lang.Number, t as WatchUi.SlideType) as Void {
        AppState.selectedBook = book;
        AppState.selectedChapter = chapter;
        Perf.markOpen();
        var view = ReaderPrep.take(book, chapter, targetFor(book, chapter));
        if (view == null) {
            view = new ReaderView();
        } else {
            (view as ReaderView).adoptPrepared();
        }
        var pr = pendingRange;
        pendingRange = null;
        if (pr != null) {
            (view as ReaderView).showRange(pr[0] as Lang.Number, pr[1] as Lang.Number,
                                           pr[2] as Lang.Number, pr[3] as Lang.Number);
        }
        Nav.push(view, new ReaderDelegate(view), t);
    }
}

class ReaderDelegate extends WatchUi.BehaviorDelegate {
    var _view as ReaderView;
    var _keys as KeyHold;

    function initialize(view as ReaderView) {
        BehaviorDelegate.initialize();
        _view = view;
        // Critique #3: hold START bookmarks the verse (toast); a short START opens the menu on
        // release. Critique #12: hold DOWN keeps stepping. See KeyHold for the device TODO.
        _keys = new KeyHold(method(:shortStart), method(:holdStart), method(:repeatDown));
    }

    function onKeyPressed(evt as WatchUi.KeyEvent) as Lang.Boolean {
        if (!_view.selPick) {
            _keys.pressed(evt.getKey());
        }
        return false;
    }

    function onKeyReleased(evt as WatchUi.KeyEvent) as Lang.Boolean {
        _keys.released(evt.getKey());
        return false;
    }

    //! Critique #8: no settle gate for buttons (only taps can be aimed at the previous screen).
    function shortStart() as Void {
        _view.openMenu();
    }

    function holdStart() as Void {
        _view.bookmarkFocusedVerse();
    }

    function repeatDown() as Void {
        step(1, false);
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
        _view.noteInput();
        if (dir > 0) {
            _view.ensureAhead();
        }
        var before = AppState.scroll.scrollOffset;
        if (page) {
            AppState.scroll.page(dir);
        } else if (dir > 0) {
            AppState.scroll.next();
        } else {
            AppState.scroll.prev();
        }
        if (AppState.scroll.scrollOffset != before) {
            Feedback.step(); // a detent per verse / line actually moved, none at the ends
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
        if (_view.selPick) {
            if (k == WatchUi.KEY_ENTER) {
                _view.confirmRange();
                return true;
            }
            if (k == WatchUi.KEY_DOWN || k == WatchUi.KEY_UP) {
                _view.extendRange(k == WatchUi.KEY_DOWN ? 1 : -1);
                return true;
            }
            return false;
        }
        _view.clearRange(); // an opened range's highlight ends on the first press
        if (k == WatchUi.KEY_ENTER) {
            return true; // acted on at release (KeyHold): short = menu, hold = bookmark
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
        if (_view.selPick) {
            return true;
        }
        if (InputGate.accept(_view.shownAt, System.getTimer())) {
            _view.bookmarkFocusedVerse();
        }
        return true;
    }

    function onTap(evt) as Lang.Boolean {
        if (_view.selPick) {
            _view.confirmRange();
            return true;
        }
        _view.clearRange();
        // Taps meant for the grid (mash during the open flash) must not open this menu.
        if (InputGate.accept(_view.shownAt, System.getTimer())) {
            _view.openMenu();
        }
        return true;
    }

    function onSwipe(evt) as Lang.Boolean {
        var dir = evt.getDirection();
        if (_view.selPick) {
            if (dir == WatchUi.SWIPE_UP || dir == WatchUi.SWIPE_DOWN) {
                _view.extendRange(dir == WatchUi.SWIPE_UP ? 1 : -1);
            } else if (dir == WatchUi.SWIPE_RIGHT) {
                TouchGuard.markBack();
                _view.clearRange(); // swipe right = cancel the pick
            }
            return true;
        }
        _view.clearRange();
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
            Nav.pop(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onMenu() as Lang.Boolean {
        if (_view.selPick) {
            return true;
        }
        _view.openMenu();
        return true;
    }

    function onBack() as Lang.Boolean {
        if (TouchGuard.consumeBack()) {
            return true;
        }
        if (_view.selPick) {
            _view.clearRange(); // BACK = cancel the pick, stay in the reader
            return true;
        }
        // SPEC: return to grid for *current* (possibly continued) chapter.
        syncCurrentFromFocus();
        Nav.pop(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
