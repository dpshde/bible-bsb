using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class BookListView extends Ui.View {
    // Layout constants
    private const HEADER_HEIGHT = 14;
    private const LINE_HEIGHT = 14;
    private const MARGIN_X = 4;
    private const SCROLL_BAR_X = 172; // right edge on 176-wide screen
    private const SCROLL_BAR_WIDTH = 3;

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
        drawHeader(dc, width);

        // Draw divider line
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawLine(0, HEADER_HEIGHT, width, HEADER_HEIGHT);

        // Get filtered books
        var app = getApp();
        var state = app.state;
        var filterOpt = BibleBooks.getFilterOption(state.filterIndex);
        var filteredBooks = state.getFilteredBookIndices();

        if (filteredBooks.size() == 0) {
            dc.drawText(
                width / 2,
                height / 2,
                Graphics.FONT_SMALL,
                "No books",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }

        // Calculate visible range
        var contentHeight = height - HEADER_HEIGHT - 2;
        var maxVisible = contentHeight / LINE_HEIGHT;
        if (maxVisible < 1) {
            maxVisible = 1;
        }

        var totalBooks = filteredBooks.size();
        var scroll = state.bookScroll;
        if (scroll > totalBooks - maxVisible) {
            scroll = totalBooks - maxVisible;
        }
        if (scroll < 0) {
            scroll = 0;
        }

        // Draw book list
        for (var i = 0; i < maxVisible; i++) {
            var bookListIdx = scroll + i;
            if (bookListIdx >= totalBooks) {
                break;
            }

            var bookIndex = filteredBooks[bookListIdx] as Number;
            var y = HEADER_HEIGHT + 2 + (i * LINE_HEIGHT);
            var isSelected = (bookIndex == state.selectedBookIndex);

            if (isSelected) {
                // Highlighted row: black background, white text
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(0, y, width, LINE_HEIGHT);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            } else {
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
            }

            var bookName = BibleBooks.getBookName(bookIndex);
            dc.drawText(
                MARGIN_X,
                y + (LINE_HEIGHT / 2) - 1,
                Graphics.FONT_SMALL,
                bookName,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // Draw scroll indicator if needed
        if (totalBooks > maxVisible) {
            drawScrollIndicator(dc, scroll, totalBooks, maxVisible, height);
        }
    }

    private function drawHeader(dc as Graphics.Dc, width as Number) as Void {
        var app = getApp();
        var state = app.state;
        var filterOpt = BibleBooks.getFilterOption(state.filterIndex);

        var headerText;
        if (filterOpt == null || filterOpt.length() == 0 || filterOpt.equals("All")) {
            headerText = "< All >";
        } else {
            headerText = "< " + filterOpt + " >";
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawText(
            width / 2,
            HEADER_HEIGHT / 2 - 1,
            Graphics.FONT_SMALL,
            headerText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawScrollIndicator(
        dc as Graphics.Dc,
        scroll as Number,
        total as Number,
        maxVisible as Number,
        height as Number
    ) as Void {
        var trackTop = HEADER_HEIGHT + 2;
        var trackBottom = height - 2;
        var trackHeight = trackBottom - trackTop;

        if (trackHeight <= 0) {
            return;
        }

        var thumbHeight = (maxVisible * trackHeight / total);
        if (thumbHeight < 4) {
            thumbHeight = 4;
        }

        var scrollableRange = total - maxVisible;
        var thumbY;
        if (scrollableRange <= 0) {
            thumbY = trackTop;
        } else {
            thumbY = trackTop + (scroll * (trackHeight - thumbHeight) / scrollableRange);
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.fillRectangle(SCROLL_BAR_X, thumbY, SCROLL_BAR_WIDTH, thumbHeight);
    }

    private function getApp() as BibleApp {
        return Application.getApp() as BibleApp;
    }
}
