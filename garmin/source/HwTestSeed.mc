using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

//! Simulator round-trip builds only (annotation `hwtest`, excluded from every normal build): the
//! throwaway test key comes from a resource outside the repo and is written into the app's
//! settings, as if typed in Garmin Connect. Normal builds compile the empty module below.
(:hwtest)
module HwTestSeed {
    function apply() as Void {
        var k = Application.Properties.getValue(HwSync.PROP_KEY);
        if (k == null || (k as Lang.String).length() == 0) {
            Application.Properties.setValue(HwSync.PROP_KEY, WatchUi.loadResource(Rez.Strings.HwTestKey) as Lang.String);
            Application.Properties.setValue(HwSync.PROP_ON, true);
            HwSync.settingsChanged();
        }
    }
}

(:nohwtest)
module HwTestSeed {
    function apply() as Void {
    }
}
