using Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class ReaderView extends Ui.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        var app = getApp();
        var state = app.state;
        var ref = state.getDisplayRef();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2 - 10,
            Graphics.FONT_SMALL,
            ref,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2 + 10,
            Graphics.FONT_SMALL,
            "Reader",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function getApp() as BibleApp {
        return Application.getApp() as BibleApp;
    }
}
