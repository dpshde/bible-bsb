using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Slim reader menu — scroll mode toggle without colliding with hold-bookmark.
class ReaderMenuView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var mode = AppState.scroll.mode == ScrollModel.MODE_VERSE ? "Verse" : "Line";
        RoundLayout.drawCenteredInChord(dc, h / 2 - 20, "Scroll: " + mode, Graphics.FONT_SMALL);
        RoundLayout.drawCenteredInChord(dc, h / 2 + 10, "Select=toggle  Back=close", Graphics.FONT_TINY);
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
        var msg = AppState.scroll.mode == ScrollModel.MODE_VERSE ? "Verse scroll" : "Line scroll";
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _reader.showToast(msg);
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
