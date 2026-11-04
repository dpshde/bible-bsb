using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

//! Capture harness only (PREVIEW stays false in every shipped build): renders the real
//! BsbGlanceView into a glance-sized bitmap at the focused slot of the device glance loop
//! (mid-screen, system icon at its left), because the simulator's glance mode pins the slot to
//! the top of the screen where the round mask crops it.
module GlancePreview {
    const PREVIEW = false;

    // [glance DC width, height, left x] for the target, set by the capture script (gp.sh)
    // from the simulator measurement (5:40 PM).
    const SLOT = [217, 88, 49];
}

class GlancePreviewView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var sw = dc.getWidth();
        var sh = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var s = GlancePreview.SLOT;
        var w = s[0] as Lang.Number;
        var h = s[1] as Lang.Number;
        var x0 = s[2] as Lang.Number;
        var y0 = (sh - h) / 2;
        var bmp = Graphics.createBufferedBitmap({:width => w, :height => h}).get() as Graphics.BufferedBitmap;
        new BsbGlanceView().onUpdate(bmp.getDc());
        dc.drawBitmap(x0, y0, bmp);
        var icon = WatchUi.loadResource(Rez.Drawables.LauncherIcon) as Graphics.BitmapType;
        var iw = icon.getWidth();
        dc.drawBitmap(x0 - iw - 6, (sh - icon.getHeight()) / 2, icon);
    }
}
