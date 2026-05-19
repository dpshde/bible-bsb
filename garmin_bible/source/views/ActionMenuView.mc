using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Application;

class ActionMenuView extends Ui.View {
    // Menu items
    private const ITEM_SAVE = 0;
    private const ITEM_SHARE = 1;
    private const ITEM_BACK = 2;
    private const ITEM_COUNT = 3;

    var selectedItem as Number;
    var parentView as Ui.View;

    function initialize(parent as Ui.View) {
        View.initialize();
        selectedItem = 0;
        parentView = parent;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var app = getApp();
        var state = app.state;

        // Compute layout
        var layout = BibleLayout.computeLayout(dc);

        // First, draw the parent reader view content dimmed behind us
        drawParentBehind(dc, state, layout);

        // Draw overlay
        drawOverlay(dc, width, height, layout);
    }

    private function drawParentBehind(
        dc as Graphics.Dc,
        state as BibleState,
        layout as Dictionary
    ) as Void {
        var headerText = state.getDisplayRef();
        if (headerText == null || headerText.length() == 0) {
            headerText = "(unknown)";
        }

        if (state.readerIsLoading) {
            BibleRenderer.renderEmptyPage(dc, layout, headerText,
                WatchUi.loadResource(Rez.Strings.Loading) as String);
        } else if (state.readerError != null && (state.readerError as String).length() > 0) {
            BibleRenderer.renderEmptyPage(dc, layout, headerText, state.readerError as String);
        } else if (state.readerLines == null || state.readerLines.size() == 0) {
            BibleRenderer.renderEmptyPage(dc, layout, headerText,
                WatchUi.loadResource(Rez.Strings.ErrorLoadFailed) as String);
        } else {
            var lineCount = state.readerLines.size();
            var linesPerPage = state.readerLinesPerPage;
            if (linesPerPage < 1) {
                linesPerPage = 1;
            }
            var totalPages = BibleRenderer.computeTotalPages(lineCount, linesPerPage);
            var currentPage = BibleRenderer.scrollToPage(state.readerScroll, linesPerPage);
            currentPage = BibleRenderer.clampPage(currentPage, totalPages);
            var pageIndicator = BibleRenderer.buildPageIndicator(currentPage, totalPages);
            BibleRenderer.renderPage(
                dc,
                state.readerLines,
                state.readerScroll,
                layout,
                headerText,
                pageIndicator
            );
        }
    }

    private function drawOverlay(
        dc as Graphics.Dc,
        width as Number,
        height as Number,
        layout as Dictionary
    ) as Void {
        var bgColor = layout.get("bgColor") as Number;
        var textColor = layout.get("textColor") as Number;
        var accentColor = layout.get("accentColor") as Number;
        var fontSize = layout.get("fontSize") as Number;

        // Dim the background by drawing a semi-transparent-ish band
        // On 1-bit we just draw a white rectangle band; on color we could
        // use a solid overlay. For simplicity, draw a solid band.
        dc.setColor(bgColor, bgColor);
        var overlayTop = (height / 2) - 22;
        var overlayHeight = 44;
        dc.fillRectangle(0, overlayTop, width, overlayHeight);

        // Draw border
        dc.setColor(textColor, textColor);
        dc.drawRectangle(2, overlayTop + 1, width - 4, overlayHeight - 2);

        // Draw menu items
        var itemLabels = ["Save", "Share", "Back"] as Array<String>;
        var itemY = overlayTop + 2;
        var lineH = layout.get("lineHeight") as Number;
        if (lineH < 1) {
            lineH = 1;
        }

        for (var i = 0; i < ITEM_COUNT; i++) {
            if (i == selectedItem) {
                dc.setColor(bgColor, textColor);
                dc.fillRectangle(4, itemY, width - 8, lineH);
                dc.setColor(bgColor, textColor);
            } else {
                dc.setColor(textColor, bgColor);
            }

            BibleRenderer.drawContentText(
                dc,
                fontSize,
                8,
                itemY + 1,
                itemLabels[i]
            );
            itemY = itemY + lineH;
        }
    }

    private function getApp() as BibleApp {
        return Application.getApp() as BibleApp;
    }
}
