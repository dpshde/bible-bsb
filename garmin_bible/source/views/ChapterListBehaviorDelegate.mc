using Toybox.Application;
import Toybox.Lang;
using Toybox.WatchUi as Ui;

// Placeholder ChapterListBehaviorDelegate — will be fully implemented by the chapter-verse-views feature.
class ChapterListBehaviorDelegate extends Ui.BehaviorDelegate {
    var view as Ui.View;

    function initialize(v as Ui.View) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onBack() as Boolean {
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }
}
