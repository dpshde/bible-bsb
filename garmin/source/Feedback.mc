using Toybox.Attention;
using Toybox.Lang;
using Toybox.System;

//! Haptic tick for a committed tap (chapter / filter cell). Respects the watch's
//! vibration setting and devices without a motor.
module Feedback {
    // POKE: TAP_VIBE — duty % and ms of the confirm tick.
    const VIBE_DUTY = 40;
    const VIBE_MS = 30;
    // POKE: TAP_FLASH_MS — gold flash on the tapped cell before it opens (80-120 ms).
    const FLASH_MS = 100;

    function tick() as Void {
        if (!(Attention has :vibrate)) {
            return;
        }
        var s = System.getDeviceSettings();
        if ((s has :vibrateOn) && !s.vibrateOn) {
            return;
        }
        Attention.vibrate([new Attention.VibeProfile(VIBE_DUTY, VIBE_MS)]);
    }
}
