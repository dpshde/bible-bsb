using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class BookFilterView extends Ui.View {
    // Layout constants for 5-column grid
    private const COLS = 5;
    private const CELL_W = 34;  // 170/5 = 34 (fits within 176 width with margins)
    private const CELL_H = 16;
    private const HEADER_HEIGHT = 14;
    private const MARGIN_X = 2;
    private const MARGIN_Y = 2;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Clear background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        // Draw header
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawText(
            width / 2,
            HEADER_HEIGHT / 2 - 1,
            Graphics.FONT_SMALL,
            "Select Filter",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Draw divider line
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawLine(0, HEADER_HEIGHT, width, HEADER_HEIGHT);

        // Get current filter index from app state
        var app = getApp();
        var state = app.state;
        var selectedFilter = state.filterIndex;

        var totalOptions = BibleBooks.FILTER_COUNT;
        var totalRows = (totalOptions + COLS - 1) / COLS;

        // Calculate visible rows
        var contentTop = HEADER_HEIGHT + MARGIN_Y;
        var contentHeight = height - contentTop - MARGIN_Y;
        var maxVisibleRows = contentHeight / CELL_H;
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

        // Draw grid cells
        for (var i = 0; i < totalOptions; i++) {
            var row = i / COLS;
            var col = i % COLS;

            if (row < startRow || row >= startRow + maxVisibleRows) {
                continue;
            }

            var displayRow = row - startRow;
            var x = MARGIN_X + (col * CELL_W);
            var y = contentTop + (displayRow * CELL_H);
            var isSelected = (i == selectedFilter);

            if (isSelected) {
                // Highlighted cell: black background, white text
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(x, y, CELL_W - 2, CELL_H - 2);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            } else {
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
            }

            var opt = BibleBooks.getFilterOption(i);
            dc.drawText(
                x + (CELL_W / 2) - 1,
                y + (CELL_H / 2) - 1,
                Graphics.FONT_SMALL,
                opt,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // Draw scroll indicator if needed
        if (totalRows > maxVisibleRows) {
            drawScrollIndicator(dc, startRow, totalRows, maxVisibleRows, contentTop, contentHeight);
        }
    }

    private function drawScrollIndicator(
        dc as Graphics.Dc,
        startRow as Number,
        totalRows as Number,
        maxVisibleRows as Number,
        contentTop as Number,
        contentHeight as Number
    ) as Void {
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

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.fillRectangle(172, thumbY, 3, thumbHeight);
    }

    private function getApp() as BibleApp {
        return Application.getApp() as BibleApp;
    }
}
