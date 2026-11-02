using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Slim reader menu — scroll mode toggle without colliding with hold-bookmark.
class ReaderMenuView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var w = dc.getWidth();
        var mode = AppState.scroll.mode == ScrollModel.MODE_VERSE ? "Verse" : "Line";
        dc.drawText(w / 2, dc.getHeight() / 2 - 20, Graphics.FONT_SMALL,
            "Scroll: " + mode, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, dc.getHeight() / 2 + 10, Graphics.FONT_TINY,
            "Select=toggle  Back=close", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class ReaderMenuDelegate extends WatchUi.BehaviorDelegate {
    var _reader as ReaderView;

    function initialize(reader as ReaderView) {
        BehaviorDelegate.initialize();
        _reader = reader;
    }

    function onSelect() as Lang.Boolean {
        AppState.scroll.toggleMode();
        _reader.toast = AppState.scroll.mode == ScrollModel.MODE_VERSE ? "Verse scroll" : "Line scroll";
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
