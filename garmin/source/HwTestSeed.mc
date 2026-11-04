using Toybox.Application;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

//! Simulator round-trip builds only (annotation `hwtest`, excluded from every normal build): the
//! test-library key comes from a resource outside the repo and is written into the app's
//! settings, as if typed in Garmin Connect. Normal builds compile the empty module below.
(:hwtest)
module HwTestSeed {
    function apply() as Void {
        var k = Application.Properties.getValue(HwSync.PROP_KEY);
        if (k == null || (k as Lang.String).length() == 0) {
            Application.Properties.setValue(HwSync.PROP_KEY, WatchUi.loadResource(Rez.Strings.HwTestKey) as Lang.String);
            Application.Properties.setValue(HwSync.PROP_ON, true);
            if (Rez.Strings has :HwTestServer) { // error-path builds: a server URL that doesn't answer
                Application.Properties.setValue(HwSync.PROP_SERVER, WatchUi.loadResource(Rez.Strings.HwTestServer) as Lang.String);
            }
            HwSync.settingsChanged();
        }
    }

    //! Round-trip check: highlights per color as the watch sees them (compare with sync.js).
    function report(cnt as Lang.Dictionary, names as Lang.Dictionary) as Void {
        var ks = HwMap.sortStrs(cnt.keys());
        var t = "";
        for (var i = 0; i < ks.size(); i++) {
            t += (i > 0 ? " " : "") + ks[i] + "(" + HwMap.colorLabel(ks[i] as Lang.String, names) + ")=" + cnt[ks[i]];
        }
        System.println("HWSYNC view colors " + t);
    }
}

(:nohwtest)
module HwTestSeed {
    function apply() as Void {
    }
    function report(cnt as Lang.Dictionary, names as Lang.Dictionary) as Void {
    }
}
