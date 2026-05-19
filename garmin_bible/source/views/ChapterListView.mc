using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

// Placeholder ChapterListView — will be fully implemented by the chapter-verse-views feature.
class ChapterListView extends Ui.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        var app = Application.getApp() as BibleApp;
        var state = app.state;
        var bookName = BibleBooks.getBookName(state.bookIndex);

        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2 - 10,
            Graphics.FONT_SMALL,
            bookName,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2 + 10,
            Graphics.FONT_SMALL,
            "Chapter List",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
