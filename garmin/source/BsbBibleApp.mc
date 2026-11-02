using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

class BsbBibleApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart/onStop also run in the GLANCE process, where only (:glance) code is loaded:
    // app-only init lives in getInitialView, and onStop flushes only if the app view ran.
    var _appStarted as Lang.Boolean = false;

    function onStart(state) as Void {
    }

    function onStop(state) as Void {
        if (_appStarted) {
            LastReadApp.flush();
        }
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new BsbGlanceView()];
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        Palette.loadTheme(); // persisted Dark/Light (Application.Storage "theme")
        LastReadApp.restore(); // resume book/chapter/verse (Storage "last")
        _appStarted = true;
        return [new BookListView(), new BookListDelegate()];
    }
}
