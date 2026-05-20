using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class VerseSelectView extends Ui.View {
    private const ROW_SPACING = 10;

    var layout as Dictionary?;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        layout = BibleLayout.computeLayout(dc);
        var safeLayout = layout as Dictionary;

        var marginX = safeLayout.get("marginX") as Number;
        var textColor = safeLayout.get("textColor") as Number;
        var bgColor = safeLayout.get("bgColor") as Number;
        var fontSize = safeLayout.get("fontSize") as Number;
        var lineHeight = BibleLayout.getListRowHeight(safeLayout);
        if (lineHeight < 1) {
            lineHeight = 1;
        }

        // Clear background
        dc.setColor(textColor, bgColor);
        dc.clear();

        // Get app state
        var app = getApp();
        var state = app.state;
        var bookName = BibleBooks.getBookName(state.bookIndex);

        // Draw header via BibleLayout
        BibleLayout.drawHeader(dc, safeLayout, bookName + " " + state.chapter);

        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        if (maxVerse <= 0) {
            maxVerse = 40;
        }

        // Clamp displayed verse values to valid range
        var displayStart = state.startVerse;
        var displayEnd = state.endVerse;
        if (displayStart < 1) { displayStart = 1; }
        if (displayStart > maxVerse) { displayStart = maxVerse; }
        if (displayEnd < 1) { displayEnd = 1; }
        if (displayEnd > maxVerse) { displayEnd = maxVerse; }
        if (displayEnd < displayStart) { displayEnd = displayStart; }

        var contentTop = safeLayout.get("contentTop") as Number;
        var contentBottom = safeLayout.get("contentBottom") as Number;
        var row1Y = contentTop + ROW_SPACING;
        var row2Y = row1Y + lineHeight;
        var row3Y = row2Y + lineHeight;
        var hintY = row3Y + lineHeight + 4;
        var screenHeight = dc.getHeight();
        if (hintY > contentBottom - 8) {
            hintY = contentBottom - 8;
        }

        // Row 1: "All verses"
        var allSelected = (state.verseSelectMode == 0);
        drawRow(dc, safeLayout, row1Y, lineHeight, "All verses", allSelected);

        // Row 2: "Start: N"
        var startSelected = (state.verseSelectMode == 1);
        drawRow(dc, safeLayout, row2Y, lineHeight, "Start: " + displayStart, startSelected);

        // Row 3: "End: N"
        var endSelected = (state.verseSelectMode == 2);
        drawRow(dc, safeLayout, row3Y, lineHeight, "End: " + displayEnd, endSelected);

        // Bottom hint
        dc.setColor(textColor, bgColor);
        var hint;
        if (state.verseSelectMode == 0) {
            hint = "OK=read, Back=back";
        } else {
            hint = "L/R=vs OK=read";
        }
        var hintFont = Graphics.FONT_TINY;
        if (fontSize == BibleLayout.FONT_TINY) {
            hintFont = Graphics.FONT_TINY;
        }
        dc.drawText(
            BibleLayout.getSafeRowCenterX(safeLayout, hintY, 8),
            hintY,
            hintFont,
            hint,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawRow(
        dc as Graphics.Dc,
        layout as Dictionary,
        y as Number,
        rowHeight as Number,
        text as String,
        isSelected as Boolean
    ) as Void {
        var marginX = layout.get("marginX") as Number;
        var textColor = layout.get("textColor") as Number;
        var bgColor = layout.get("bgColor") as Number;
        var fontSize = layout.get("fontSize") as Number;

        BibleLayout.drawSelectableRow(dc, layout, y - (rowHeight / 2), rowHeight, text, isSelected, marginX);
    }

    private function getApp() as BibleApp {
        return Application.getApp() as BibleApp;
    }
}
