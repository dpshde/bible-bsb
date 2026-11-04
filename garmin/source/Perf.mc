using Toybox.Lang;
using Toybox.System;

//! Perf probes: ms per onUpdate / key + resource loads + text measures per frame.
//! (:debug) build prints "PERF ..." to the sim console; (:release) compiles to no-ops.
module Perf {
    var loads as Lang.Number = 0;
    var measures as Lang.Number = 0;
    var texts as Lang.Number = 0;
    var peak as Lang.Number = 0; // drawText calls this frame (device-cost proxy: TTF raster)

    (:debug)
    function start() as Lang.Number {
        loads = 0;
        measures = 0;
        texts = 0;
        return System.getTimer();
    }

    (:debug)
    function end(tag as Lang.String, t0 as Lang.Number) as Void {
        var st = System.getSystemStats();
        if (st.usedMemory > peak) {
            peak = st.usedMemory;
        }
        System.println("PERF " + tag + " ms=" + (System.getTimer() - t0) + " loads=" + loads + " measures=" + measures
            + " texts=" + texts + " memKB=" + (st.usedMemory / 1024) + " peakKB=" + (peak / 1024)
            + " totalKB=" + (st.totalMemory / 1024));
    }

    //! Light probe (no memory stats): "PERF <tag> ms=<n>" — custom menu rows, title, mask.
    (:debug)
    function lite(tag as Lang.String, t0 as Lang.Number) as Void {
        System.println("PERF " + tag + " ms=" + (System.getTimer() - t0));
    }

    (:release)
    function lite(tag as Lang.String, t0 as Lang.Number) as Void {
    }

    //! Non-frame probe: "<tag> ms=<n>" (e.g. VIBE: cost of one Attention.vibrate call).
    (:debug)
    function probe(tag as Lang.String, t0 as Lang.Number) as Void {
        System.println(tag + " ms=" + (System.getTimer() - t0));
    }

    (:release)
    function probe(tag as Lang.String, t0 as Lang.Number) as Void {
    }

    (:debug)
    function now() as Lang.Number {
        return System.getTimer();
    }

    (:release)
    function now() as Lang.Number {
        return 0;
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

    //! Chapter-open probe: openFor() marks, the reader's first finished onUpdate prints
    //! "OPEN reader ms=<push..first paint>". Debug builds only.
    var openT as Lang.Number = 0;

    (:debug)
    function markOpen() as Void {
        openT = System.getTimer();
    }

    (:debug)
    function firstPaint(tag as Lang.String) as Void {
        if (openT != 0) {
            System.println("OPEN " + tag + " ms=" + (System.getTimer() - openT));
            openT = 0;
        }
    }

    //! Idle (Timer) work probe: "IDLE <tag> ms=<n>" per tick that did work.
    (:debug)
    function idle(tag as Lang.String, t0 as Lang.Number) as Void {
        System.println("IDLE " + tag + " ms=" + (System.getTimer() - t0));
    }

    (:release)
    function markOpen() as Void {
    }

    (:release)
    function firstPaint(tag as Lang.String) as Void {
    }

    (:release)
    function idle(tag as Lang.String, t0 as Lang.Number) as Void {
    }

    //! Fallback log (abbreviations etc.): println in every build so a device log shows it.
    var _noted as Lang.Dictionary = {};

    function note(msg as Lang.String) as Void {
        if (_noted[msg] == null) {
            _noted[msg] = true;
            System.println("NOTE " + msg);
        }
    }
}
