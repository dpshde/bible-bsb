using Toybox.Lang;
using Toybox.WatchUi;

//! The app's visible name comes from ONE string resource, Rez.Strings.AppName
//! (resources/strings/strings.xml), which the manifest also uses for the store / app list /
//! glance label. "Bible BSB" is temporary (Dylan 2026-11-03): a rename is that one line.
module AppInfo {
    var _name as Lang.String or Null = null;

    function name() as Lang.String {
        if (_name == null) {
            _name = WatchUi.loadResource(Rez.Strings.AppName) as Lang.String;
        }
        return _name as Lang.String;
    }
}
