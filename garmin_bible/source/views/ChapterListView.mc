using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class ChapterListView extends Ui.View {
    private const COLS = 5;
    private const CELL_W = 34;
    private const CELL_H = 16;
    private const MAX_VISIBLE_ROWS = 3;

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
        var marginY = safeLayout.get("marginTop") as Number;
        var textColor = safeLayout.get("textColor") as Number;
        var bgColor = safeLayout.get("bgColor") as Number;
        var selectBg = safeLayout.get("selectBg") as Number;
        var selectText = safeLayout.get("selectText") as Number;
        var fontSize = safeLayout.get("fontSize") as Number;

        // Clear background
        dc.setColor(textColor, bgColor);
        dc.clear();

        // Get app state
        var app = getApp();
        var state = app.state;
        var bookName = BibleBooks.getBookName(state.bookIndex);

        // Draw header via BibleLayout
        BibleLayout.drawHeader(dc, safeLayout, bookName);

        var maxChapter = BibleBooks.getChapterCount(state.bookIndex);
        if (maxChapter <= 0 || state.bookIndex < 0 || state.bookIndex >= BibleBooks.BOOK_COUNT) {
            BibleLayout.drawMessage(dc, safeLayout, "No chapters");
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
        for (var row = startRow; row < startRow + MAX_VISIBLE_ROWS && row < totalRows; row++) {
            for (var col = 0; col < COLS; col++) {
                var chapterNum = row * COLS + col + 1;
                if (chapterNum > maxChapter) {
                    break;
                }

                var displayRow = row - startRow;
                var x = marginX + (col * CELL_W);
                var y = BibleLayout.HEADER_HEIGHT + marginY + (displayRow * CELL_H);
                var isSelected = (chapterNum == state.chapter);

                if (isSelected) {
                    dc.setColor(selectBg, selectText);
                    dc.fillRectangle(x, y, CELL_W - 2, CELL_H - 2);
                    dc.setColor(selectText, selectBg);
                } else {
                    dc.setColor(textColor, bgColor);
                }

                dc.drawText(
                    x + (CELL_W / 2) - 1,
                    y + (CELL_H / 2) - 1,
                    cellFont,
                    chapterNum.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
            }
        }

        // Draw scroll indicator if needed
        if (totalRows > MAX_VISIBLE_ROWS) {
            drawScrollIndicator(dc, safeLayout, startRow, totalRows, MAX_VISIBLE_ROWS, height);
        }
    }

    private function drawScrollIndicator(
        dc as Graphics.Dc,
        layout as Dictionary,
        startRow as Number,
        totalRows as Number,
        maxVisibleRows as Number,
        height as Number
    ) as Void {
        var textColor = layout.get("textColor") as Number;
        var bgColor = layout.get("bgColor") as Number;
        var width = layout.get("screenWidth") as Number;
        var marginX = layout.get("marginX") as Number;
        var scrollBarX = width - marginX - 3;
        if (scrollBarX < 0) {
            scrollBarX = 0;
        }

        var trackTop = BibleLayout.HEADER_HEIGHT + layout.get("marginTop") as Number;
        var trackBottom = height - layout.get("marginBottom") as Number;
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

        dc.setColor(textColor, bgColor);
        dc.fillRectangle(scrollBarX, thumbY, 3, thumbHeight);
    }

    private function getApp() as BibleApp {
        return Application.getApp() as BibleApp;
    }
}
