import Toybox.Lang;
using Toybox.WatchUi as Ui;

class BookListBehaviorDelegate extends Ui.BehaviorDelegate {
    var view as Ui.View;

    function initialize(v as Ui.View) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onMenu() as Boolean {
        return true;
    }

    function onSelect() as Boolean {
        return true;
    }

    function onBack() as Boolean {
        return false;
    }
}
