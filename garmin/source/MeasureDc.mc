using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;

//! Off-screen Dc for text measuring outside onUpdate (Timer slices, key handlers), so
//! background wrapping never has to force a repaint just to borrow the screen Dc.
module MeasureDc {
    var _ref = null;
    var _sw as Lang.Number = 0;
    var _sh as Lang.Number = 0;

    function screenW() as Lang.Number {
        if (_sw == 0) {
            var ds = System.getDeviceSettings();
            _sw = ds.screenWidth;
            _sh = ds.screenHeight;
        }
        return _sw;
    }

    function screenH() as Lang.Number {
        screenW();
        return _sh;
    }

    function get() as Graphics.Dc or Null {
        if (!(Graphics has :createBufferedBitmap)) {
            return null;
        }
        var bmp = _ref != null ? (_ref as Graphics.BufferedBitmapReference).get() : null;
        if (bmp == null) {
            _ref = Graphics.createBufferedBitmap({:width => 1, :height => 1});
            bmp = (_ref as Graphics.BufferedBitmapReference).get();
        }
        return bmp != null ? (bmp as Graphics.BufferedBitmap).getDc() : null;
    }
}
