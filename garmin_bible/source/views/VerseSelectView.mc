using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class VerseSelectView extends Ui.View {
    // Layout constants
    private const HEADER_HEIGHT = 14;
    private const LINE_HEIGHT = 14;
    private const MARGIN_X = 4;
    private const ROW_1_Y = HEADER_HEIGHT + 10;
    private const ROW_2_Y = ROW_1_Y + LINE_HEIGHT;
    private const ROW_3_Y = ROW_2_Y + LINE_HEIGHT;
    private const HINT_Y = 58;

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
        var maxVerse = BibleBooks.getVerseCount(state.bookIndex, state.chapter);
        if (maxVerse <= 0) {
            maxVerse = 40;
        }

        // Draw header: "Book Chapter"
        var headerText = bookName + " " + state.chapter;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawText(
            width / 2,
            HEADER_HEIGHT / 2 - 1,
            Graphics.FONT_SMALL,
            headerText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Draw divider line
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawLine(0, HEADER_HEIGHT, width, HEADER_HEIGHT);

        // Row 1: "All verses"
        var allSelected = (state.verseSelectMode == 0);
        drawRow(dc, width, ROW_1_Y, "All verses", allSelected);

        // Row 2: "Start: N"
        var startSelected = (state.verseSelectMode == 1);
        var startLabel = "Start: " + state.startVerse;
        drawRow(dc, width, ROW_2_Y, startLabel, startSelected);

        // Row 3: "End: N"
        var endSelected = (state.verseSelectMode == 2);
        var endLabel = "End: " + state.endVerse;
        drawRow(dc, width, ROW_3_Y, endLabel, endSelected);

        // Bottom hint
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        var hint;
        if (state.verseSelectMode == 0) {
            hint = "OK=read, Back=back";
        } else {
            hint = "L/R=vs OK=read";
        }
        dc.drawText(
            width / 2,
            HINT_Y,
            Graphics.FONT_TINY,
            hint,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawRow(
        dc as Graphics.Dc,
        width as Number,
        y as Number,
        text as String,
        isSelected as Boolean
    ) as Void {
        if (isSelected) {
            // Highlighted row: black background, white text
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.fillRectangle(0, y - 10, width, LINE_HEIGHT);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        } else {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        }

        dc.drawText(
            MARGIN_X,
            y,
            Graphics.FONT_SMALL,
            text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function getApp() as BibleApp {
        return Application.getApp() as BibleApp;
    }
}
