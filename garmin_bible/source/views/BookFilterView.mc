using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class BookFilterView extends Ui.View {
    private const COLS = 5;

    var layout as Dictionary?;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        layout = BibleLayout.computeLayout(dc);
        var safeLayout = layout as Dictionary;

        var width = dc.getWidth();
        var height = dc.getHeight();
        var marginX = safeLayout.get("marginX") as Number;
        var marginTop = safeLayout.get("marginTop") as Number;
        var marginBottom = safeLayout.get("marginBottom") as Number;
        var textColor = safeLayout.get("textColor") as Number;
        var bgColor = safeLayout.get("bgColor") as Number;
        var selectBg = safeLayout.get("selectBg") as Number;
        var selectText = safeLayout.get("selectText") as Number;
        var fontSize = safeLayout.get("fontSize") as Number;

        // Clear background
        dc.setColor(textColor, bgColor);
        dc.clear();

        // Draw header via BibleLayout
        BibleLayout.drawHeader(dc, safeLayout, "Select Filter");

        // Get current filter index from app state
        var app = getApp();
        var state = app.state;
        var selectedFilter = state.filterIndex;

        var totalOptions = BibleBooks.FILTER_COUNT;
        var totalRows = (totalOptions + COLS - 1) / COLS;

        // Derive cell dimensions from layout
        var contentTop = safeLayout.get("contentTop") as Number;
        var contentBottom = safeLayout.get("contentBottom") as Number;
        var contentHeight = contentBottom - contentTop;
        var contentWidth = safeLayout.get("contentWidth") as Number;
        var cellW = contentWidth / COLS;
        if (cellW < 1) {
            cellW = 1;
        }
        var cellH = safeLayout.get("lineHeight") as Number;
        if (cellH < 1) {
            cellH = 1;
        }

        var maxVisibleRows = contentHeight / cellH;
        if (maxVisibleRows < 1) {
            maxVisibleRows = 1;
        }

        // Determine which row range to show
        var selectedRow = selectedFilter / COLS;
        var startRow;
        if (selectedRow >= maxVisibleRows - 1) {
            startRow = selectedRow - maxVisibleRows + 1;
        } else {
            startRow = 0;
        }
        if (startRow < 0) {
            startRow = 0;
        }

        // Font for cells
        var cellFont;
        if (fontSize == BibleLayout.FONT_LARGE) {
            cellFont = Graphics.FONT_LARGE;
        } else if (fontSize == BibleLayout.FONT_MEDIUM) {
            cellFont = Graphics.FONT_MEDIUM;
        } else if (fontSize == BibleLayout.FONT_TINY) {
            cellFont = Graphics.FONT_TINY;
        } else {
            cellFont = Graphics.FONT_SMALL;
        }

        // Draw grid cells
        for (var i = 0; i < totalOptions; i++) {
            var row = i / COLS;
            var col = i % COLS;

            if (row < startRow || row >= startRow + maxVisibleRows) {
                continue;
            }

            var displayRow = row - startRow;
            var x = marginX + (col * cellW);
            var y = contentTop + (displayRow * cellH);
            var isSelected = (i == selectedFilter);

            if (isSelected) {
                dc.setColor(selectBg, selectText);
                dc.fillRectangle(x, y, cellW - 2, cellH - 2);
                dc.setColor(selectText, selectBg);
            } else {
                dc.setColor(textColor, bgColor);
            }

            var opt = BibleBooks.getFilterOption(i);
            dc.drawText(
                x + (cellW / 2) - 1,
                y + (cellH / 2) - 1,
                cellFont,
                opt,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // Draw scroll indicator if needed
        if (totalRows > maxVisibleRows) {
            drawScrollIndicator(dc, safeLayout, startRow, totalRows, maxVisibleRows, contentTop, contentHeight);
        }
    }

    private function drawScrollIndicator(
        dc as Graphics.Dc,
        layout as Dictionary,
        startRow as Number,
        totalRows as Number,
        maxVisibleRows as Number,
        contentTop as Number,
        contentHeight as Number
    ) as Void {
        var textColor = layout.get("textColor") as Number;
        var bgColor = layout.get("bgColor") as Number;
        var width = layout.get("screenWidth") as Number;
        var marginX = layout.get("marginX") as Number;
        var scrollBarX = width - marginX - 3;
        if (scrollBarX < 0) {
            scrollBarX = 0;
        }

        var trackTop = contentTop;
        var trackHeight = contentHeight;
        var thumbHeight = (maxVisibleRows * trackHeight / totalRows);
        if (thumbHeight < 4) {
            thumbHeight = 4;
        }

        var scrollableRange = totalRows - maxVisibleRows;
        var thumbY;
        if (scrollableRange <= 0) {
            thumbY = trackTop;
        } else {
            thumbY = trackTop + (startRow * (trackHeight - thumbHeight) / scrollableRange);
        }

        dc.setColor(textColor, bgColor);
        dc.fillRectangle(scrollBarX, thumbY, 3, thumbHeight);
    }

    private function getApp() as BibleApp {
        return Application.getApp() as BibleApp;
    }
}
