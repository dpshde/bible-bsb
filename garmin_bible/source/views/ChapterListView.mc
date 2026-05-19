using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class ChapterListView extends Ui.View {
    // Layout constants for 5-column grid
    private const COLS = 5;
    private const CELL_W = 34;  // 170/5 = 34 (fits within 176 width with margins)
    private const CELL_H = 16;
    private const HEADER_HEIGHT = 14;
    private const MARGIN_X = 2;
    private const MARGIN_Y = 2;
    private const MAX_VISIBLE_ROWS = 3;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Clear background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        // Get app state
        var app = getApp();
        var state = app.state;
        var bookName = BibleBooks.getBookName(state.bookIndex);
        var maxChapter = BibleBooks.getChapterCount(state.bookIndex);

        // Draw header: book name
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawText(
            width / 2,
            HEADER_HEIGHT / 2 - 1,
            Graphics.FONT_SMALL,
            bookName,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Draw divider line
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawLine(0, HEADER_HEIGHT, width, HEADER_HEIGHT);

        if (maxChapter <= 0) {
            dc.drawText(
                width / 2,
                height / 2,
                Graphics.FONT_SMALL,
                "No chapters",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }

        var totalRows = (maxChapter + COLS - 1) / COLS;
        if (totalRows < 1) {
            totalRows = 1;
        }

        var selectedRow = (state.chapter - 1) / COLS;

        // Determine which row range to show
        var startRow;
        if (selectedRow >= MAX_VISIBLE_ROWS) {
            startRow = selectedRow - MAX_VISIBLE_ROWS + 1;
        } else {
            startRow = 0;
        }
        if (startRow < 0) {
            startRow = 0;
        }

        // Draw grid cells
        for (var row = startRow; row < startRow + MAX_VISIBLE_ROWS && row < totalRows; row++) {
            for (var col = 0; col < COLS; col++) {
                var chapterNum = row * COLS + col + 1;
                if (chapterNum > maxChapter) {
                    break;
                }

                var displayRow = row - startRow;
                var x = MARGIN_X + (col * CELL_W);
                var y = HEADER_HEIGHT + MARGIN_Y + (displayRow * CELL_H);
                var isSelected = (chapterNum == state.chapter);

                if (isSelected) {
                    // Highlighted cell: black background, white text
                    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                    dc.fillRectangle(x, y, CELL_W - 2, CELL_H - 2);
                    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                } else {
                    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
                }

                dc.drawText(
                    x + (CELL_W / 2) - 1,
                    y + (CELL_H / 2) - 1,
                    Graphics.FONT_SMALL,
                    chapterNum.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
            }
        }

        // Draw scroll indicator if needed
        if (totalRows > MAX_VISIBLE_ROWS) {
            drawScrollIndicator(dc, startRow, totalRows, MAX_VISIBLE_ROWS, height);
        }
    }

    private function drawScrollIndicator(
        dc as Graphics.Dc,
        startRow as Number,
        totalRows as Number,
        maxVisibleRows as Number,
        height as Number
    ) as Void {
        var trackTop = HEADER_HEIGHT + MARGIN_Y;
        var trackBottom = height - MARGIN_Y;
        var trackHeight = trackBottom - trackTop;

        if (trackHeight <= 0) {
            return;
        }

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
