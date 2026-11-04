using Toybox.Lang;
using Toybox.Timer;
using Toybox.WatchUi;

//! Button holds, timed between onKeyPressed and onKeyReleased (Connect IQ has no hold event for
//! buttons; hold UP arrives as MENU and is left alone). UX critique #3, #5, #1/#12.
//! - START: a hold of HOLD_MS fires `onHold` once, and the release then does nothing; a shorter
//!   press fires `onShort` on release (so a hold never also opens the menu).
//! - DOWN: after REPEAT_DELAY_MS held, `onRepeat` fires every REPEAT_MS until release (the press
//!   itself already stepped once through onKey).
//! TODO(real Enduro 3): verify hold START isn't taken by the system inside an app, that
//! onKeyReleased always arrives for START, and that hold DOWN isn't a user shortcut that
//! fires first. The simulator delivers press/release for every button.
class KeyHold {
    // POKE: HOLD_START_MS — hold START this long to bookmark (reader) / chapter-bookmark (grid).
    const HOLD_MS = 600;
    // POKE: REPEAT_DELAY_MS / REPEAT_MS — hold DOWN to keep stepping.
    const REPEAT_DELAY_MS = 450;
    const REPEAT_MS = 120;

    var _timer as Timer.Timer or Null = null;
    var _key as Lang.Number = -1;
    var _fired as Lang.Boolean = false;
    var _onShort as Lang.Method or Null;
    var _onHold as Lang.Method or Null;
    var _onRepeat as Lang.Method or Null;

    function initialize(onShort as Lang.Method or Null, onHold as Lang.Method or Null, onRepeat as Lang.Method or Null) {
        _onShort = onShort;
        _onHold = onHold;
        _onRepeat = onRepeat;
    }

    //! True when START is handled here (press deferred to release); false for other keys.
    function handlesEnter() as Lang.Boolean {
        return _onShort != null;
    }

    function pressed(key as Lang.Number) as Void {
        stop();
        _key = key;
        _fired = false;
        if (key == WatchUi.KEY_ENTER && _onHold != null) {
            start(HOLD_MS);
        } else if (key == WatchUi.KEY_DOWN && _onRepeat != null) {
            start(REPEAT_DELAY_MS);
        }
    }

    function released(key as Lang.Number) as Void {
        var wasKey = _key == key;
        stop();
        _key = -1;
        if (wasKey && key == WatchUi.KEY_ENTER && !_fired && _onShort != null) {
            Perf.nav("start");
            (_onShort as Lang.Method).invoke();
        }
    }

    function onTimer() as Void {
        if (_key == WatchUi.KEY_ENTER) {
            _fired = true;
            (_onHold as Lang.Method).invoke();
        } else if (_key == WatchUi.KEY_DOWN) {
            _fired = true;
            (_onRepeat as Lang.Method).invoke();
            start(REPEAT_MS);
        }
    }

    function start(ms as Lang.Number) as Void {
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
        (_timer as Timer.Timer).start(method(:onTimer), ms, false);
    }

    function stop() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
        }
    }
}
