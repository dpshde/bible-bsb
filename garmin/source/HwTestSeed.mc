using Toybox.Application;
using Toybox.Lang;
using Toybox.System;
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
            if (Rez.Strings has :HwTestServer) { // error-path builds: a server URL that doesn't answer
                Application.Properties.setValue(HwSync.PROP_SERVER, WatchUi.loadResource(Rez.Strings.HwTestServer) as Lang.String);
            }
            HwSync.settingsChanged();
        }
    }

    //! Round-trip check: the watch's view (chosen color + verses in it), compared with sync.js.
    function report(color, verses as Lang.Array) as Void {
        var vs = HwMap.sortStrs(verses.slice(0, null));
        var t = "";
        for (var i = 0; i < vs.size(); i++) { t += (i > 0 ? " " : "") + vs[i]; }
        System.println("HWSYNC view color=" + color + " verses=" + t);
    }
}

(:nohwtest)
module HwTestSeed {
    function apply() as Void {
    }
    function report(color, verses as Lang.Array) as Void {
    }
}
