using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class BookListView extends Ui.View {
    private const SCROLL_BAR_WIDTH = 3;

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
        var textColor = safeLayout.get("textColor") as Number;
        var bgColor = safeLayout.get("bgColor") as Number;
        var selectBg = safeLayout.get("selectBg") as Number;
        var selectText = safeLayout.get("selectText") as Number;
        var fontSize = safeLayout.get("fontSize") as Number;
        var lineHeight = safeLayout.get("lineHeight") as Number;
        if (lineHeight < 1) {
            lineHeight = 1;
        }

        // Clear background
        dc.setColor(textColor, bgColor);
        dc.clear();

        // Draw header
        BibleLayout.drawHeader(dc, safeLayout, buildHeaderText());

        // Get filtered books
        var app = getApp();
        var state = app.state;
        var filteredBooks = state.getFilteredBookIndices();

        if (filteredBooks == null || filteredBooks.size() == 0) {
            BibleLayout.drawMessage(dc, safeLayout, "No books");
            return;
        }

        // Calculate visible range
        var contentTop = safeLayout.get("contentTop") as Number;
        var contentBottom = safeLayout.get("contentBottom") as Number;
        var contentHeight = contentBottom - contentTop;
        var maxVisible = contentHeight / lineHeight;
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
            var y = contentTop + (i * lineHeight);
            var isSelected = (bookIndex == state.selectedBookIndex);

            if (isSelected) {
                dc.setColor(selectBg, selectText);
                dc.fillRectangle(0, y, width, lineHeight);
                dc.setColor(selectText, selectBg);
            } else {
                dc.setColor(textColor, bgColor);
            }

            var bookName = BibleBooks.getBookName(bookIndex);
            var font;
            if (fontSize == BibleLayout.FONT_LARGE) {
                font = Graphics.FONT_LARGE;
            } else if (fontSize == BibleLayout.FONT_MEDIUM) {
                font = Graphics.FONT_MEDIUM;
            } else if (fontSize == BibleLayout.FONT_TINY) {
                font = Graphics.FONT_TINY;
            } else {
                font = Graphics.FONT_SMALL;
            }
            dc.drawText(
                marginX,
                y + (lineHeight / 2) - 1,
                font,
                bookName,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // Draw scroll indicator if needed
        if (totalBooks > maxVisible) {
            drawScrollIndicator(dc, safeLayout, scroll, totalBooks, maxVisible, height);
        }
    }

    private function buildHeaderText() as String {
        var app = getApp();
        var state = app.state;
        var filterOpt = BibleBooks.getFilterOption(state.filterIndex);

        if (filterOpt == null || filterOpt.length() == 0 || filterOpt.equals("All")) {
            return "< All >";
        } else {
            return "< " + filterOpt + " >";
        }
    }

    private function drawScrollIndicator(
        dc as Graphics.Dc,
        layout as Dictionary,
        scroll as Number,
        total as Number,
        maxVisible as Number,
        height as Number
    ) as Void {
        var textColor = layout.get("textColor") as Number;
        var bgColor = layout.get("bgColor") as Number;
        var width = layout.get("screenWidth") as Number;
        var marginX = layout.get("marginX") as Number;
        var marginTop = layout.get("marginTop") as Number;
        var marginBottom = layout.get("marginBottom") as Number;
        var scrollBarX = width - marginX - SCROLL_BAR_WIDTH;
        if (scrollBarX < 0) {
            scrollBarX = 0;
        }

        var trackTop = marginTop + BibleLayout.HEADER_HEIGHT;
        var trackBottom = height - marginBottom;
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

        dc.setColor(textColor, bgColor);
        dc.fillRectangle(scrollBarX, thumbY, SCROLL_BAR_WIDTH, thumbHeight);
    }

    private function getApp() as BibleApp {
        return Application.getApp() as BibleApp;
    }
}
