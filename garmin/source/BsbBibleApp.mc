using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

class BsbBibleApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) as Void {
    }

    function onStop(state) as Void {
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new BookListView(), new BookListDelegate()];
    }
}
