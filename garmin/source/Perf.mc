using Toybox.Lang;
using Toybox.System;

//! Perf probes: ms per onUpdate / key + resource loads + text measures per frame.
//! (:debug) build prints "PERF ..." to the sim console; (:release) compiles to no-ops.
module Perf {
    var loads as Lang.Number = 0;
    var measures as Lang.Number = 0;

    (:debug)
    function start() as Lang.Number {
        loads = 0;
        measures = 0;
        return System.getTimer();
    }

    (:debug)
    function end(tag as Lang.String, t0 as Lang.Number) as Void {
        System.println("PERF " + tag + " ms=" + (System.getTimer() - t0) + " loads=" + loads + " measures=" + measures);
    }

    var _seg as Lang.String = "";
    var _segT as Lang.Number = 0;

    (:debug)
    function seg(tag as Lang.String) as Void {
        var t = System.getTimer();
        _seg = _seg + " " + tag + "=" + (t - _segT);
        _segT = t;
    }

    (:debug)
    function segStart() as Void {
        _seg = "";
        _segT = System.getTimer();
    }

    (:debug)
    function segEnd() as Void {
        System.println("SEG" + _seg);
    }

    (:release)
    function seg(tag as Lang.String) as Void {
    }

    (:release)
    function segStart() as Void {
    }

    (:release)
    function segEnd() as Void {
    }

    (:release)
    function start() as Lang.Number {
        return 0;
    }

    (:release)
    function end(tag as Lang.String, t0 as Lang.Number) as Void {
    }
}
