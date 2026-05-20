using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Application;

class ReaderView extends Ui.View {
    var layout as Dictionary?;
    var pendingVerses as Array<Dictionary>?;
    var isAlive as Boolean;

    function initialize() {
        View.initialize();
        pendingVerses = null;
        isAlive = true;
    }

    function onHide() as Void {
        isAlive = false;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var app = getApp();
        var state = app.state;

        // Compute layout on first draw
        if (layout == null) {
            layout = BibleLayout.computeLayout(dc);
        }
        var safeLayout = layout as Dictionary;

        // If there are pending verses that arrived before first onUpdate, wrap them now
        if (pendingVerses != null) {
            var contentWidth = safeLayout.get("contentWidth") as Number;
            var charWidth = safeLayout.get("charWidth") as Number;
            var linesPerPage = safeLayout.get("linesPerPage") as Number;
            var wrapped = BibleRenderer.wrapVerses(pendingVerses as Array<Dictionary>, contentWidth, charWidth);
            state.readerLines = wrapped;
            state.readerLinesPerPage = linesPerPage;
            pendingVerses = null;
            Ui.requestUpdate();
        }

        // Validate passage state — show error if invalid
        if (!BibleError.isValidPassageState(state)) {
            var fallbackRef = "(unknown)";
            if (state != null) {
                var ref = state.getDisplayRef();
                if (ref != null && ref.length() > 0) {
                    fallbackRef = ref;
                }
            }
            BibleRenderer.renderEmptyPage(
                dc,
                safeLayout,
                fallbackRef,
                BibleError.MSG_LOAD_FAILED
            );
            return;
        }

        var headerText = state.getDisplayRef();
        if (headerText == null || headerText.length() == 0) {
            headerText = BibleError.MSG_UNKNOWN;
        }

        if (state.readerIsLoading) {
            BibleRenderer.renderEmptyPage(
                dc,
                safeLayout,
                headerText,
                WatchUi.loadResource(Rez.Strings.Loading) as String
            );
            return;
        }

        if (state.readerError != null && (state.readerError as String).length() > 0) {
            BibleRenderer.renderEmptyPage(
                dc,
                safeLayout,
                headerText,
                state.readerError as String
            );
            return;
        }

        if (state.readerLines == null || state.readerLines.size() == 0) {
            BibleRenderer.renderEmptyPage(
                dc,
                safeLayout,
                headerText,
                WatchUi.loadResource(Rez.Strings.ErrorLoadFailed) as String
            );
            return;
        }

        var lineCount = state.readerLines.size();
        var linesPerPage = state.readerLinesPerPage;
        if (linesPerPage < 1) {
            linesPerPage = 1;
        }
        var totalPages = BibleRenderer.computeTotalPages(lineCount, linesPerPage);
        var currentPage = BibleRenderer.scrollToPage(state.readerScroll, linesPerPage);
        currentPage = BibleRenderer.clampPage(currentPage, totalPages);

        var pageIndicator = BibleRenderer.buildPageIndicator(currentPage, totalPages);

        renderReaderPage(dc, state, safeLayout, headerText, pageIndicator);

        // Draw toast if active
        drawToastIfActive(dc, state, safeLayout);
    }

    private function drawToastIfActive(
        dc as Graphics.Dc,
        state as BibleState,
        layout as Dictionary
    ) as Void {
        if (!state.isToastActive()) {
            return;
        }
        var width = dc.getWidth();
        var height = dc.getHeight();
        var bgColor = layout.get("bgColor") as Number;
        var textColor = layout.get("textColor") as Number;
        var fontSize = layout.get("fontSize") as Number;
        var msg = state.readerToastMessage;

        // Toast box in center-bottom
        var toastY = height - 24;
        dc.setColor(textColor, textColor);
        dc.fillRectangle(8, toastY, width - 16, 16);
        dc.setColor(bgColor, textColor);
        BibleRenderer.drawMessageText(dc, fontSize, width / 2, toastY + 8, msg);
    }

    function onShow() as Void {
        layout = null;

        var app = getApp();
        var state = app.state;

        // Clear old lines before loading new chapter (memory safety)
        state.readerLines = [] as Array<Dictionary>;
        state.readerScroll = 0;
        state.readerError = "";
        state.readerIsLoading = true;
        state.readerLinesPerPage = 1;

        // Validate passage state before attempting any fetch
        if (!BibleError.isValidPassageState(state)) {
            state.readerIsLoading = false;
            state.readerError = BibleError.MSG_LOAD_FAILED;
            Ui.requestUpdate();
            return;
        }

        var bookIndex = state.bookIndex;
        var chapter = state.chapter;
        var startVerse = state.startVerse;
        var endVerse = state.endVerse;

        // Clamp to safe bounds before loading
        var clamped = BibleError.clampVerseRange(bookIndex, chapter, startVerse, endVerse);
        startVerse = clamped[0];
        endVerse = clamped[1];
        state.startVerse = startVerse;
        state.endVerse = endVerse;

        // Check offline first, then API
        if (BibleApi.isOfflineAvailable(bookIndex, chapter)) {
            var verses = BibleApi.loadFromResource(bookIndex, chapter);
            if (verses != null && verses.size() > 0) {
                finishLoad(verses, startVerse, endVerse);
                return;
            }
        }

        // Online fetch
        BibleApi.fetchChapter(bookIndex, chapter, method(:onChapterResponse));
    }

    function onChapterResponse(
        responseCode as Number,
        data as Dictionary or String or Null
    ) as Void {
        if (!isAlive) {
            return;
        }

        var app = getApp();
        var state = app.state;

        if (responseCode != 200 || data == null) {
            // Try offline fallback
            if (BibleApi.isOfflineAvailable(state.bookIndex, state.chapter)) {
                var verses = BibleApi.loadFromResource(state.bookIndex, state.chapter);
                if (verses != null && verses.size() > 0) {
                    finishLoad(verses, state.startVerse, state.endVerse);
                    return;
                }
            }

            var errorMsg;
            if (responseCode == 404) {
                errorMsg = WatchUi.loadResource(Rez.Strings.ErrorChapterNotFound) as String;
            } else if (responseCode < 0) {
                errorMsg = WatchUi.loadResource(Rez.Strings.ErrorNoConnection) as String;
            } else {
                errorMsg = WatchUi.loadResource(Rez.Strings.ErrorLoadFailed) as String;
            }
            state.readerIsLoading = false;
            state.readerError = errorMsg;
            Ui.requestUpdate();
            return;
        }

        var verses = BibleApi.parseResponse(data);
        if (verses == null || verses.size() == 0) {
            state.readerIsLoading = false;
            state.readerError = WatchUi.loadResource(Rez.Strings.ErrorLoadFailed) as String;
            Ui.requestUpdate();
            return;
        }

        finishLoad(verses, state.startVerse, state.endVerse);
    }

    function finishLoad(
        verses as Array<Dictionary>,
        startVerse as Number,
        endVerse as Number
    ) as Void {
        if (!isAlive) {
            return;
        }

        var app = getApp();
        var state = app.state;

        // Filter to verse range if needed
        var filtered = [] as Array<Dictionary>;
        for (var i = 0; i < verses.size(); i++) {
            var v = verses[i] as Dictionary;
            var num = v.get("verseNumber") as Number;
            if (num >= startVerse && num <= endVerse) {
                filtered.add(v);
            }
        }

        // Always word-wrap before storing readerLines — never store raw verses
        if (layout != null) {
            var safeLayout = layout as Dictionary;
            var contentWidth = safeLayout.get("contentWidth") as Number;
            var charWidth = safeLayout.get("charWidth") as Number;
            var linesPerPage = safeLayout.get("linesPerPage") as Number;

            var wrapped = BibleRenderer.wrapVerses(filtered, contentWidth, charWidth);

            state.readerLines = wrapped;
            state.readerScroll = 0;
            state.readerLinesPerPage = linesPerPage;
            state.readerIsLoading = false;
            state.readerError = "";
        } else {
            // Layout not yet computed (no onUpdate has run).
            // Store filtered verses pending — they will be wrapped on first onUpdate
            // when layout is computed from the DC.
            pendingVerses = filtered;
            state.readerLines = [] as Array<Dictionary>;
            state.readerScroll = 0;
            state.readerLinesPerPage = 1;
            state.readerIsLoading = false;
            state.readerError = "";
        }

        Ui.requestUpdate();
    }

    private function renderReaderPage(
        dc as Graphics.Dc,
        state as BibleState,
        layout as Dictionary,
        headerText as String,
        pageIndicator as String
    ) as Void {
        BibleRenderer.renderPage(
            dc,
            state.readerLines,
            state.readerScroll,
            layout,
            headerText,
            pageIndicator
        );
    }

    private function getApp() as BibleApp {
        return Application.getApp() as BibleApp;
    }
}
