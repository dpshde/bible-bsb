using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;
using Toybox.System;

//! Haptics. tick(): confirm tick for a committed tap (chapter / filter cell). step(): a light
//! detent for each scroll step through books, chapters, filters and verses (v7). Both respect
//! the watch's own vibration setting and do nothing on watches without a motor.
module Feedback {
    // POKE: TAP_VIBE — duty % and ms of the confirm tick.
    const VIBE_DUTY = 40;
    const VIBE_MS = 30;
    // POKE: STEP_VIBE — scroll detent: short and light so fast scrolling stays a soft ticking.
    const STEP_DUTY = 25;
    const STEP_MS = 12;
    // POKE: STEP_MIN_GAP_MS — at most one detent per this many ms (drag / momentum / mashing).
    const STEP_MIN_GAP_MS = 45;
    // POKE: TAP_FLASH_MS — gold flash on the tapped cell before it opens (80-120 ms).
    const FLASH_MS = 100;

    // Settings > Tap vibration (default on). The watch's own vibration setting still wins.
    const STORAGE_KEY = "vibe";
    // Settings > Vibrate on scroll (default on).
    const STEP_KEY = "vibeScroll";

    function enabled() as Lang.Boolean {
        return readFlag(STORAGE_KEY);
    }

    function setEnabled(on as Lang.Boolean) as Void {
        Application.Storage.setValue(STORAGE_KEY, on);
    }

    function stepEnabled() as Lang.Boolean {
        return readFlag(STEP_KEY);
    }

    function setStepEnabled(on as Lang.Boolean) as Void {
        Application.Storage.setValue(STEP_KEY, on);
        _stepOn = null;
    }

    function readFlag(key as Lang.String) as Lang.Boolean {
        var v = Application.Storage.getValue(key);
        return !(v instanceof Lang.Boolean) || v;
    }

    //! True when this watch has a motor and its vibration setting is on (read once per
    //! refresh(), not per step: getDeviceSettings allocates).
    var _motor as Lang.Boolean or Null = null;

    function motor() as Lang.Boolean {
        if (_motor == null) {
            var ok = Attention has :vibrate;
            if (ok) {
                var s = System.getDeviceSettings();
                if ((s has :vibrateOn) && !s.vibrateOn) {
                    ok = false;
                }
            }
            _motor = ok;
        }
        return _motor as Lang.Boolean;
    }

    //! Re-read the watch's vibration setting and ours (app start, home screen shown).
    function refresh() as Void {
        _motor = null;
        _stepOn = null;
    }

    function tick() as Void {
        if (!enabled() || !motor()) {
            return;
        }
        Attention.vibrate([new Attention.VibeProfile(VIBE_DUTY, VIBE_MS)]);
    }

    var _stepOn as Lang.Boolean or Null = null; // cached Storage flag
    var _stepProfile = null;                     // one VibeProfile array, reused
    var _lastStep as Lang.Number = -100000;
    var lastStepMs as Lang.Number = 0;           // debug: cost of the last vibrate() call

    //! One scroll step happened (the caller already knows focus actually moved).
    function step() as Void {
        if (_stepOn == null) {
            _stepOn = stepEnabled();
        }
        if (!(_stepOn as Lang.Boolean) || !motor()) {
            return;
        }
        var t = System.getTimer();
        if (t - _lastStep < STEP_MIN_GAP_MS) {
            return;
        }
        _lastStep = t;
        if (_stepProfile == null) {
            _stepProfile = [new Attention.VibeProfile(STEP_DUTY, STEP_MS)];
        }
        Attention.vibrate(_stepProfile as Lang.Array<Attention.VibeProfile>);
        lastStepMs = System.getTimer() - t;
        Perf.probe("VIBE", t);
    }
}
