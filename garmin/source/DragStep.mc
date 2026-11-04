using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

//! 0.9.7 (Dylan, real Enduro 3: touch scroll "a smidge laggy"). onSwipe arrives only once the
//! finger lifts and the gesture is classified (sim: 115-140 ms after the first touch event), so
//! menus, grids and the reader stepped late. DragStep steps on the drag itself: the first step
//! as soon as the finger has moved START_PX vertically, then (lists) one more per `perPx`. The
//! swipe / page behavior the OS derives from the same gesture is then swallowed (swallow()).
class DragStep {
    // POKE: DRAG_START_PX — vertical travel before the first step (taps jitter a few px).
    const START_PX = 12;
    // POKE: DRAG_SWALLOW_MS — after a drag step, the gesture's own onSwipe / onNextPage are
    // dropped for this long (they arrive right after the finger lifts).
    const SWALLOW_MS = 400;

    var _step as Lang.Method;
    var _perPx as Lang.Number; // px of travel per further step; 0 = one step per gesture
    var _x0 as Lang.Number = 0;
    var _y0 as Lang.Number = 0;
    var _active as Lang.Boolean = false;
    var _done as Lang.Number = 0;  // steps taken this gesture (+ next, - previous)
    var _at as Lang.Number = -100000;

    //! step: Method(dir as Number) -> Void, dir +1 = next (finger moves up), -1 = previous.
    function initialize(step as Lang.Method, perPx as Lang.Number) {
        _step = step;
        _perPx = perPx;
    }

    function onDrag(evt as WatchUi.DragEvent) as Lang.Boolean {
        var c = evt.getCoordinates();
        var x = c[0] as Lang.Number;
        var y = c[1] as Lang.Number;
        var t = evt.getType();
        if (t == WatchUi.DRAG_TYPE_START) {
            Perf.touch("drag");
            _x0 = x;
            _y0 = y;
            _active = true;
            _done = 0;
            return true;
        }
        if (!_active) {
            return false;
        }
        var dy = _y0 - y; // > 0: finger moved up = next
        var ady = dy < 0 ? -dy : dy;
        var adx = x - _x0 < 0 ? _x0 - x : x - _x0;
        var want = 0;
        if (ady >= START_PX && ady > adx) { // vertical only: a swipe right (back) never scrolls
            var n = _perPx > 0 ? 1 + (ady - START_PX) / _perPx : 1;
            want = dy > 0 ? n : -n;
        }
        // Lists follow the finger both ways within one gesture; one-step targets (reader page,
        // grid) step once and never take it back.
        while (_done != want && (_perPx > 0 || _done == 0)) {
            var d = _done < want ? 1 : -1;
            _done += d;
            _at = System.getTimer();
            _step.invoke(d);
        }
        if (t == WatchUi.DRAG_TYPE_STOP) {
            _active = false;
        }
        return true;
    }

    //! True while (or right after) a drag stepped: the gesture's onSwipe / onNextPage must not
    //! move focus a second time.
    function swallow() as Lang.Boolean {
        return (_active && _done != 0) || System.getTimer() - _at < SWALLOW_MS;
    }
}
