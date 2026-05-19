using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class BibleApp extends Application.AppBase {
    var state as BibleState;

    function initialize() {
        AppBase.initialize();
        state = new BibleState();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() {
        var view = new BookListView();
        var delegate = new BookListBehaviorDelegate();
        return [view, delegate];
    }
}

function getApp() as BibleApp {
    return Application.getApp() as BibleApp;
}
