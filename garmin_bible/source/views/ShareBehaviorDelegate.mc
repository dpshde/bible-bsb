using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

class ShareBehaviorDelegate extends Ui.BehaviorDelegate {
    var shareView as ShareView;

    function initialize(view as ShareView) {
        BehaviorDelegate.initialize();
        shareView = view;
    }

    // Back button: return to the previous view (Reader or Collection)
    function onBack() as Boolean {
        Ui.popView(Ui.SLIDE_DOWN);
        return true;
    }
}
